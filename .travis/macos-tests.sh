#!/bin/zsh

# Runs t3 with the specified arguments and echoes the command line to stdout.
t3_() {
    echo "+ t3 $@"
    ./t3 "$@"
}

# Install Docker mockup
mkdir -p /usr/local/bin
cp .travis/docker-mock.sh /usr/local/bin/docker
chmod 755 /usr/local/bin/docker
docker reset

export T3_ENGINE=docker


# Set environment variables for the current job
source .travis/setenv.inc

echo $'\n*************** Testing '"TYPO3 v$TYPO3_VER, image $PRIMARY_IMG"

# Test help and error handling
#source .travis/messages.inc

# Test with Docker mockup
#t3_ run -s

#t3_ stop -s

# Read log
HOSTNAME=$(hostname)

cat .travis/linux.log | while read -r LOG_LINE; do
    case "$LOG_LINE" in
        '+ '*)
            # Command found, execute it and save output and exit status
            CMD="./${LOG_LINE#+ }"

            echo "$CMD"
            ${=CMD} | \
                tee | \
                sed -e 's/typo3\.'$HOSTNAME'/typo3.travis-job/'
            EXIT_STATUS=${pipestatus[1]}
            ;;

        '= '*)
            # Exit status found, compare with most recent exit status
            echo "...... $LOG_LINE = $EXIT_STATUS"
            echo
            ;;

        '')
            # Skip empty lines
            ;;

        *)
            # Logged output line, compare with next output line
            # of most recent command
            echo '?       '"$LOG_LINE"
            ;;
    esac
done

true
