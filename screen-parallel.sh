#!/bin/bash

SCREEN=`which screen`
CRLF=$'\n'

PROGRAM_FILE=$(basename "$0")

DATA_FILE=input.txt

#SESSION=parallel.$$
SESSION=parallel.$$
TMPDIR=/tmp/parallel.$$


VERBOSE=0
DATA_FILE=""
CONCURRENCY=3
DELAY=1
DEBUG=0
PIPE=0
LEAVE_DETACHED=0

function fake-screen() {
    echo -n "SCREEN:"
    for f in "$@"; do
        echo -n " [$f]"
    done
    echo ""
}

function cmd_string() {
    # build shell execution line in one string.
    #
    # usage: cmd_string REPLACEMENT ARGS...
    #
    # If any of argument in ARGS contains "{}", it will be replaced
    # with REPLACEMENT, and cmd_string will return concatenated
    # string.  If none of ARGS contains "{}", REPLACEMENT will be
    # added as if it is the last argument in ARGS.
    #
    # If REPLACEMENT is an empty string (""), then there will be no
    # substitution.
    local -a args
    local count=0 cmdline="" input_file=$1 replaced=0

    shift

    for f in "$@"; do
        if [[ "$input_file" != "" && "$f" == "{}" ]]; then
            args[$count]="$input_file"
            replaced=1
        else
            args[$count]="$f"
        fi
        count=$((count + 1))
    done

    for f in ${args[@]}; do
        cmdline="$cmdline '$f'"
    done

    if [[ "$input_file" != "" && "$replaced" == 0 && "$PIPE" == 0 ]]; then
        cmdline="$cmdline '$input_file'"
    fi

    if [[ "$input_file" != "" && "$PIPE" != 0 ]]; then
        cmdline="cat '$input_file' | $cmdline"
    fi

    echo "$cmdline" | sed -e 's/^ *//'
}

function error() {
    echo "$PROGRAM_FILE: $*" 1>&2
}

function verbose() {
    if [[ "$VERBOSE" != 0 ]]; then
        echo "$*"
    fi
}

function cleanup() {
    error "cleanup..."
    rm -rf "$TMPDIR"
}

function prepare() {
    # usage: prepare FILE LINES

    declare -g CONCURRENCY

    file=$1
    lines=$2

    if [ -z "$file" ]; then
        echo "no file!"
        return 0
    fi

    # DEBUG only
    rm -rf /tmp/parallel*

    mkdir -p "$TMPDIR" >&/dev/null
    if [ ! -d "$TMPDIR" ]; then
        error "tmp dir '$TMPDIR' is not a directory"
        exit 1
    fi

    csplit -s -k -f "$TMPDIR/xx" -b "%08d" "$file" $((lines + 1)) "{*}"

    CONCURRENCY=$(ls $TMPDIR/xx* | wc -l)
}


function help_and_exit() {
    cat <<EOF
Parallel execution of a command using GNU screen(1)
Usage: $PROGRAM_FILE [OPTION...] COMMAND [ARG...]

    -c CONCURRENCY           set concurrency level (default: $CONCURRENCY)

    -i INPUT                 specify input data file
    -p                       send input to STDIN of COMMAND

    -d                       leave screen(1) in detached state.

    -v                       verbose mode

If no input file specified, this program will create CONCURRENCY
windows, then each window will execute COMMAND with ARGs.

Otherwise, input file will be splitted in CONCURRENCY parts, and
COMMAND will be executed per part.  If any of ARG is "{}", then it
will be substituted to the pathname of the part.  If there is none,
the pathname of the part will be appended to ARGs.

Example:

    # Split 'input.txt into 5 parts,
    # and execute "./process.sh -i PART-PATHNAME -v".
    $PROGRAM_FILE -i input.txt -c 5 ./process.sh -i {} -v

    # Run 3 instances of "standalone.sh -p"
    $PROGRAM_FILE -c 3 ./standalone.sh -p

EOF
    exit 0
}

while getopts ":i:c:d:dpvhD" opt; do
    case $opt in
        i)
            DATA_FILE=$OPTARG
            ;;
        c)
            CONCURRENCY=$OPTARG
            ;;
        d)
            LEAVE_DETACHED=1
            ;;
        D)
            DEBUG=1
            ;;
        v)
            VERBOSE=1
            ;;
        p)
            PIPE=1
            ;;
        h)
            help_and_exit
            ;;
        :)
            error "option requires an argument -- '$OPTARG'"
            exit 1
            ;;
        *)
            error "invalid option -- '$OPTARG'"
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if [[ "$DEBUG" != 0 ]]; then
    SCREEN=fake-screen
fi

if [[ "$#" == 0 ]]; then
    error "no argument"
    exit 1
fi

lines=0
if [[ "$DATA_FILE" != "" ]]; then
    total_lines=`wc -l "$DATA_FILE" | awk '{ print $1 }'`
    verbose "$DATA_FILE: $total_lines line(s)"

    if [[ $((total_lines % CONCURRENCY)) == 0 ]]; then
        lines=$((total_lines / CONCURRENCY))
    else
        lines=$((total_lines / CONCURRENCY + 1))
    fi
fi



trap "cleanup; exit 0" INT

#echo "DATA_FILE: $DATA_FILE"
#echo "lines: $lines"
prepare "$DATA_FILE" "$lines"

verbose "concurrency: $CONCURRENCY"

$SCREEN -dmS $SESSION

for f in $(seq $CONCURRENCY); do
    verbose "creating window for subset '$f'"

    if [[ "$DATA_FILE" != "" ]]; then
        title="$DATA_FILE#$f"
    else
        title="subset#$f"
    fi
    $SCREEN -r "$SESSION" -X screen -t "$title"
done
sleep $DELAY

# delete the first(0) window which will not be used.
$SCREEN -r "$SESSION" -p 0 -X stuff "exit${CRLF}"


if [[ "$DATA_FILE" != "" ]]; then
    window=1
    for f in $TMPDIR/xx*; do
        # don't know why, but screen 'exec' command seems not work
        # properly with -p option. -- cinsk

        cmdline=$(cmd_string "$f" "$@")
        $SCREEN -dr "$SESSION" -p "$window" -X stuff "${cmdline}${CRLF}"
        window=$((window + 1))
    done
else
    for f in $(seq $CONCURRENCY); do
        # don't know why, but screen 'exec' command seems not work
        # properly with -p option. -- cinsk

        cmdline=$(cmd_string "" "$@")
        $SCREEN -dr "$SESSION" -p "$f" -X stuff "${cmdline}${CRLF}"
    done
fi

if [[ "$LEAVE_DETACHED" == 0 ]]; then
    $SCREEN -r -p 1
fi

