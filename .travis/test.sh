#!/bin/bash

# Runs t3 with the specified arguments and echoes the command line to stdout.
t3() {
    set -x
    ./t3 $@
    { set +x; } 2>/dev/null
}

# Returns success if the number of containers whose names match the specified RE
# is equal to the specified number.
verify_container_count() {
    echo "verify_container_count() '$1' $2"
    test $(docker container ls --filter name='^/'"$1"'$' --format='{{.Names}}' | wc -l) -eq $2
}

# Returns success if the specified container is running.
verify_container_running() {
    echo "verify_container_running() '$1'"
    local STATUS
    STATUS=$(docker container inspect --format='{{.State.Status}}' $1 2>/dev/null) && test "$STATUS" = 'running'
}

# Returns success if the number of volumes whose names match the specified RE
# is equal to the specified number.
verify_volume_count() {
    echo "verify_volume_count() '$1' $2"
    test $(docker volume ls --filter name='^'"$1"'$' --format='{{.Name}}' | wc -l) -eq $2
}


echo $'\n*************** Testing'

source .travis/tags

# Exit with error status if any verification fails
set -e

# Will stop any running t3 configuration
trap 'set +e -x; ./t3 stop --rm; docker volume rm typo3-root typo3-data &>/dev/null' EXIT

# Test databases
for T in $TAGS; do
    # TYPO3 + SQLite (not for TYPO3 v8.7), remove stopped container
    if [ "$TYPO3_VER" != '8.7' ]; then
        echo $'\n*************** '"$TRAVIS_REPO_SLUG:$T with SQLite"
        t3 run -t $T

        # Verify that the container is running and that the volumes exist
        verify_container_running 'typo3'
        verify_volume_count 'typo3-(root|data)' 2

        # Verify that the TYPO3 installer is available at the HTTP and HTTPS ports
        sleep 5
        echo "Verifying HTTP and HTTPS connections"
        curl -Is http://127.0.0.1:8080/typo3/install.php | grep -q '200 OK'
        curl -Isk https://127.0.0.1:8443/typo3/install.php | grep -q '200 OK'

        t3 stop --rm

        # Verify that the container was removed and that the volumes still exist
        verify_container_count 'typo3' 0
        verify_volume_count 'typo3-(root|data)' 2

        # Clean up
        docker volume rm typo3-root typo3-data >/dev/null
    fi

    # TYPO3 + MariaDB/PostgreSQL, keep stopped container
    DB_PORT=3000
    for DB_TYPE in mariadb postgresql; do
        echo $'\n*************** '"$TRAVIS_REPO_SLUG:$T with $DB_TYPE"
        t3 run -d $DB_TYPE -P 127.0.0.1:$DB_PORT -t $T

        # Verify that the container is running and that the volumes exist
        verify_container_running 'typo3'
        verify_volume_count 'typo3-(root|data)' 2

        # Verify that the database is accepting connections
        sleep 5
        echo "Verifying database connections"
        case $DB_TYPE in
            mariadb)
                mysql -h 127.0.0.1 -P $DB_PORT -D t3 -u t3 --password=t3 -e 'quit' t3
                ;;

            postgresql)
                pg_isready -h 127.0.0.1 -p $DB_PORT -d t3 -U t3 -q
                ;;
        esac

        t3 stop --

        # Verify that the container was stopped and that the volumes still exist
        #verify_container_count 'typo3' 1   # container _is_ removed
        ! verify_container_running 'typo3'
        verify_volume_count 'typo3-(root|data)' 2

        # Clean up
        docker container rm typo3
        docker volume rm typo3-root typo3-data >/dev/null
    done

    # Run tests only for the first tag since all images tagged in this build are identical
    break
done

# Test 