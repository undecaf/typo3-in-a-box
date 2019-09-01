#!/bin/bash


# If $LOGFILE is a file then this function runs t3 with the specified 
# arguments, echoes the command line to stdout and appends it to $LOGFILE.
# The output generated at stdout is also appended to $T3_log.
#
# Otherwise, runs t3 with the specified arguments and just echoes the 
# command line to stdout.
t3_() {
    if [ -f "$LOGFILE" ]; then
        local CMD
        CMD=$1
        shift

        local SHOW
        local RE
        RE='run|stop|env|composer'
        [[ "$CMD" =~ $RE ]] && SHOW=-s

        echo "+ t3 $CMD $SHOW $@" | tee -a $LOGFILE
        ./t3 $CMD $SHOW "$@" | \
            tee -p | \
            sed -e 's/typo3\.'$HOSTNAME'/typo3.travis-job/' >>$LOGFILE

    else
        echo "+ t3 $@"
        ./t3 "$@"
    fi
}

# Returns success if all specified containers exist.
verify_containers_exist() {
    echo "verify_containers_exist $@"
    docker container inspect "$@" &>/dev/null
}

# Returns success if all specified containers are running.
verify_containers_running() {
    echo "verify_containers_running() $@"
    ! docker container inspect --format='{{.State.Status}}' "$@" | grep -v -q 'running'
}

# Returns success if all specified volumes exist.
verify_volumes_exist() {
    echo "verify_volumes_exist $@"
    docker volume inspect "$@" &>/dev/null
}

# Cleans up container and volumes after a test
cleanup() {
    t3_ stop --rm
    docker volume prune --force >/dev/null
}


# Exit with error status if any verification fails
set -e

# t3 command lines (prepended by '+') and generated Docker commands are saved here
LOGFILE=$(mktemp)

# TYPO3 image version under test
export T3_TAG=${TYPO3_VER}-dev

# TYPO3 v8.7 cannot use SQLite
test "$TYPO3_VER" = '8.7' && export T3_DB_TYPE=mariadb

# TYPO3 installation URLs
HOST_IP=127.0.0.1
HTTP_PORT=8080
HTTPS_PORT=8443
DB_PORT=3000
INSTALL_URL=http://$HOST_IP:$HTTP_PORT/typo3/install.php
INSTALL_URL_SECURE=https://$HOST_IP:$HTTPS_PORT/typo3/install.php

# Will stop any running t3 configuration
trap 'set +e; cleanup' EXIT

echo $'\n*************** Testing '"$TRAVIS_REPO_SLUG:${TYPO3_VER}-dev"


# Test error handling
. .travis/test/errors


# Test basic container and volume status
echo $'\n*************** Basic container and volume status'
t3_ run
verify_containers_running typo3
verify_volumes_exist typo3-root typo3-data

verify_error 'Cannot run container' ./t3 run

t3_ stop
verify_containers_exist typo3
! verify_containers_running typo3
verify_volumes_exist typo3-root typo3-data

cleanup

t3_ run

t3_ stop --rm
! verify_containers_exist typo3
verify_volumes_exist typo3-root typo3-data

docker volume prune --force >/dev/null


# Test HTTP and HTTPS connectivity
echo $'\n*************** HTTP and HTTPS connectivity'
t3_ run

echo "Getting $INSTALL_URL and $INSTALL_URL_SECURE"
sleep 5
curl -Is $INSTALL_URL | grep -q '200 OK'
curl -Isk $INSTALL_URL_SECURE | grep -q '200 OK'

cleanup

TEST_PORT=4711
TEST_URL=${INSTALL_URL/$HTTP_PORT/$TEST_PORT}

t3_ run -p $TEST_PORT,

echo "Getting $TEST_URL, $INSTALL_URL_SECURE not listening"
sleep 5
curl -Is $TEST_URL | grep -q '200 OK'
! curl -Isk $INSTALL_URL_SECURE

cleanup

TEST_URL=${TEST_URL/http:/https:}

t3_ run -p ,$TEST_PORT

echo "Getting $TEST_URL, $INSTALL_URL not listening"
sleep 5
! curl -Is $INSTALL_URL
curl -Isk $TEST_URL | grep -q '200 OK'

cleanup


# Test database connectivity
for DB_TYPE in mariadb postgresql; do
    echo $'\n*************** '"$DB_TYPE connectivity"
    t3_ run -d $DB_TYPE -P $HOST_IP:$DB_PORT

    echo "Pinging $DB_TYPE"
    sleep 5
    case $DB_TYPE in
        mariadb)
            mysql -h $HOST_IP -P $DB_PORT -D t3 -u t3 --password=t3 -e 'quit' t3
            ;;

        postgresql)
            pg_isready -h $HOST_IP -p $DB_PORT -d t3 -U t3 -q
            ;;
    esac

    cleanup
done


# Test volume names, mapping and (un-)mounting
ROOT_VOL='./root volume/root'
DB_VOL='./database volume/dbdata'

echo $'\n*************** Volume names, mapping and (un-)mounting'
T3_ROOT=$(basename "$ROOT_VOL") t3_ run -V $(basename "$DB_VOL")
verify_volumes_exist $(basename "$ROOT_VOL") $(basename "$DB_VOL")

cleanup

rm -rf "$ROOT_VOL" "$DB_VOL"
mkdir -p "$(dirname "$ROOT_VOL")" "$DB_VOL"

T3_DB_DATA="$DB_VOL" t3_ run -v "$ROOT_VOL"

verify_volumes_exist $(basename "$ROOT_VOL") $(basename "$DB_VOL")
test -O "$ROOT_VOL/public/FIRST_INSTALL"
test -G "$ROOT_VOL/public/FIRST_INSTALL"
test -d "$DB_VOL"

t3_ unmount "$ROOT_VOL" "$DB_VOL"
! test -f "$ROOT_VOL/public/FIRST_INSTALL"

t3_ mount "$ROOT_VOL"
test -f "$ROOT_VOL/public/FIRST_INSTALL"

verify_error 'Not a working directory, or already mounted' ./t3 mount "$ROOT_VOL"
verify_error 'Unable to unmount' ./t3 unmount "$DB_VOL"

cleanup


# Test container name and hostname
CONT_NAME=foo
HOST_NAME=bar

echo $'\n*************** '"Container name '$CONT_NAME' and hostname '$HOST_NAME'"
t3_ run
test "$(docker exec typo3 hostname)" = typo3.${HOSTNAME}
cleanup

T3_NAME=$CONT_NAME t3_ run -H $HOST_NAME
test "$(docker exec $CONT_NAME hostname)" = $HOST_NAME
t3_ stop -n $CONT_NAME --rm
docker volume prune --force >/dev/null


# Test Composer Mode
echo $'\n*************** Composer Mode'
t3_ run
! t3_ composer show
cleanup

t3_ run -c
t3_ composer show
cleanup


# Test host environment settings
PHP_SETTING='foo="bar"'

echo $'\n*************** Host environment settings'
t3_ run --env MODE=dev

echo "Verifying development mode"
sleep 5
curl -Is $INSTALL_URL | grep -q '^Server: Apache/.* PHP/.* OpenSSL/.*$'
curl -Is $INSTALL_URL | grep -q '^X-Powered-By: PHP/.*$'

t3_ env MODE=prod

echo "Verifying production mode"
sleep 5
curl -Is $INSTALL_URL | grep -q -v '^Server: Apache/'
curl -Is $INSTALL_URL | grep -q -v '^X-Powered-By:'

t3_ env php_${PHP_SETTING//\"/}

echo "Verifying php.ini setting"
sleep 5
docker exec -it typo3 cat /etc/php7/conf.d/zz_99_overrides.ini | grep -q -F "$PHP_SETTING"

cleanup


# Test custom certificate
CERTFILE='cert file'
CN=foo.bar

echo $'\n*************** Custom certificate'
openssl req -x509 -sha256 -days 1 \
    -newkey rsa:2048 -nodes \
    -keyout "$CERTFILE.key" \
    -subj "/CN=$CN" \
    -out "$CERTFILE.pem"

t3_ run -k "$CERTFILE.key,$CERTFILE.pem"

echo "Waiting for certificate"
sleep 5
echo | \
    openssl s_client -showcerts -servername -connect $HOST_IP:$HTTPS_PORT 2>/dev/null | \
    grep -q -F "subject=CN = $CN"
cleanup


# Remove trap
trap - EXIT


# Show the log file so that it can be copied
echo $'\n--------------- Begin log ---------------'
cat $LOGFILE
echo $'---------------  End log  ---------------\n'
rm $LOGFILE
