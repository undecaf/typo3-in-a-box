# Returns success if a certain message ($1) is generated at stdout
# by a command ($2, ...).
verify_msg() {
    echo "verify_msg: '$1'" >&2

    local MSG
    local CMD
    MSG=$1
    CMD=$2
    shift 2

    $CMD "$@" 2>/dev/null | grep -q -F "$MSG"
}

# Returns success if a certain message ($1) is generated at stderr
# by a command ($2, ...).
verify_error() {
    echo "verify_error: '$1'" >&2

    local MSG
    local CMD
    MSG=$1
    CMD=$2
    shift 2

    $CMD "$@" 2>&1 >/dev/null | grep -q -F "$MSG"
}


echo $'\n*************** Command abbreviation and help messages'
verify_msg 'Available commands' ./t3 -h
verify_msg 'Available commands' ./t3 --help
verify_msg 'Runs TYPO3' ./t3 run -h
verify_msg 'Runs TYPO3' ./t3 r -h
verify_msg 'Composer command' ./t3 c -h


echo $'\n*************** Error handling'
verify_error 'Missing command' ./t3
verify_error 'Unknown command' ./t3 nosuchcommand
verify_error 'Unknown command' ./t3 s
verify_error 'No option was found' ./t3 env
verify_error 'Container engine' ./t3 run -e nosuchengine
verify_error 'Invalid option' ./t3 run -k missingcertfile
verify_error 'Unknown database' ./t3 run -D nosuchdatabase
verify_error 'is required' ./t3 mount --
verify_error 'is required' ./t3 unmount --
