screen-parallel
===============

Synopsis
--------

    $ ./screen-parallel.sh -h
    Parallel execution of a command using GNU screen(1)
    Usage: screen-parallel.sh [OPTION...] COMMAND [ARG...]

        -c CONCURRENCY           set concurrency level (default: 3)

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
        screen-parallel.sh -i input.txt -c 5 ./process.sh -i {} -v

        # Run 3 instances of "standalone.sh -p"
        screen-parallel.sh -c 3 ./standalone.sh -p

Description
-----------

Parallel execution of commands using GNU screen.

This package provides one bash script file, which provides parallel execution of user-specified command using [GNU screen(1)](http://www.gnu.org/software/screen).

The data file you provides will be fragmented into specified number of sub-parts.  Then, the script will launch GNU screen, and create several windows, and each window will execute specified command to deal with the sub-parts.

Suppose that you have a data file, and each line represents work-item, and you want to execute your own script, say `process.sh`.  `process.sh` takes the data file as the first argument. Normally, you will run it by

    $ ./process.sh input.txt
    
If you want to divide `input.txt` into 5 pieces, and you want to run `process.sh` for each piece, then:

    $ screen-parallel.sh -i input -c 5 ./process.sh
    
If your script accepts each data from STDIN, run as:

    $ screen-parallel.sh -i input -c 5 -p ./process.sh

The script will accept command line arguments which is similar to that of find(1).  For example if you want to accept the pathname of the piece in the middle of the command-line, use "{}" to mark the position of the pathname, like:

    $ screen-parallel.sh -i input -c 5 ./process.sh -someopt1 {} -someopt2

