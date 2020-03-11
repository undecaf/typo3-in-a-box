#!/bin/bash

# Runs t3 with the specified arguments and echoes the command line to stdout.
t3_() {
    local CMD
    CMD=$1
    shift

    local TAG
    test "$CMD" = 'run' && TAG="-T $PRIMARY_TAG"

    # Generate entropy, otherwise private key generation may fail
    ls -R / &>/dev/null || true

    echo "+ ./t3 $CMD $TAG $@"
    ./t3 $CMD $TAG "$@"
}

# Returns success if all specified containers exist.
verify_containers_exist() {
    echo "verify_containers_exist: $@" >&2
    docker container inspect "$@" &>/dev/null
}

# Returns success if all specified containers are running.
verify_containers_running() {
    echo "verify_containers_running: $@" >&2
    ! docker container inspect --format='{{.State.Status}}' "$@" | grep -v -q 'running'
}

# Returns success if all specified volumes exist.
verify_volumes_exist() {
    echo "verify_volumes_exist: $@" >&2
    docker volume inspect "$@" &>/dev/null
}

# Returns success if the specified command ($2, $3, ...) succeeds 
# within some period of time ($1 in s).
verify_cmd_success() {
    local STEP=2
    local T=$1
    shift

    echo "verify_cmd_success: $@" >&2

    while ! "$@"; do
        sleep $STEP
        T=$((T-STEP))
        test $T -gt 0 || return 1
    done

    return 0
}

# Returns success if a message ($2) is found within some period 
# of time ($1 in s) in the Docker logs for container $3 (defaults
# to 'typo3').
verify_logs() {
    echo "verify_logs: '$2'" >&2

    local STEP=2
    local T=$1

    while ! docker logs "${3:-typo3}" 2>&1 | grep -q -F "$2"; do
        sleep $STEP
        T=$((T-STEP))
        test $T -gt 0 || return 1
    done

    return 0
}

# Cleans up container and volumes after a test
cleanup() {
    t3_ stop --rm
    docker volume prune --force >/dev/null
}


# Set environment variables for the current job
source .travis/setenv.inc

# TYPO3 v8.7 cannot use SQLite
RE='^8\.7.*'
[[ "$TYPO3_VER" =~ $RE ]] && export T3_DB_TYPE=mariadb || export T3_DB_TYPE=

# TYPO3 installation URLs
HOST_IP=127.0.0.1
HTTP_PORT=8080
HTTPS_PORT=8443
DB_PORT=3000
INSTALL_URL=http://$HOST_IP:$HTTP_PORT/typo3/install.php
INSTALL_URL_SECURE=https://$HOST_IP:$HTTPS_PORT/typo3/install.php

# Timeouts in s
SUCCESS_TIMEOUT=30
FAILURE_TIMEOUT=5

# Used to capture output
TEMP_FILE=$(mktemp)


echo $'\n*************** Testing '"TYPO3 v$TYPO3_VER, image $PRIMARY_IMG" >&2

# Display error line and clean up Docker
trap 'set +e; cleanup;' EXIT

# Exit with error status if any verification fails
set -e


# Test help and error handling
source .travis/messages.inc


# Test basic container and volume status
echo $'\n*************** Basic container and volume status' >&2
t3_ run
verify_containers_running typo3
verify_volumes_exist typo3-root typo3-data
verify_logs $SUCCESS_TIMEOUT "TYPO3 $TYPO3_VER"

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

t3_ run --label foo=bar
test "$(docker inspect --format '{{.Config.Labels.foo}}' typo3)" = 'bar'

cleanup


# Test logging
echo $'\n*************** Logging' >&2

echo "Verifying that the output follows the log"
t3_ run
sleep $SUCCESS_TIMEOUT    # for TYPO3 8.7, MariaDB startup will take that long

t3_ logs -f >$TEMP_FILE &
PID=$!
t3_ env
sleep $FAILURE_TIMEOUT
kill $PID
grep -q 'typo3 local0.info root: Apache/TYPO3' $TEMP_FILE

cleanup


# Test HTTP and HTTPS connectivity
echo $'\n*************** HTTP and HTTPS connectivity' >&2
t3_ run

echo "Getting $INSTALL_URL and $INSTALL_URL_SECURE" >&2
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $INSTALL_URL | grep -q '200 OK'
verify_cmd_success $SUCCESS_TIMEOUT curl -Isk $INSTALL_URL_SECURE | grep -q '200 OK'

cleanup

TEST_PORT=4711
TEST_URL=${INSTALL_URL/$HTTP_PORT/$TEST_PORT}

t3_ run -p $TEST_PORT,

echo "Getting $TEST_URL, $INSTALL_URL_SECURE not listening" >&2
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $TEST_URL | grep -q '200 OK'
! verify_cmd_success $FAILURE_TIMEOUT curl -Isk $INSTALL_URL_SECURE

cleanup

TEST_URL=${TEST_URL/http:/https:}

t3_ run -p ,$TEST_PORT

echo "Getting $TEST_URL, $INSTALL_URL not listening" >&2
verify_cmd_success $SUCCESS_TIMEOUT curl -Isk $TEST_URL | grep -q '200 OK'
! verify_cmd_success $FAILURE_TIMEOUT curl -Is $INSTALL_URL

cleanup


# Test databases
for DB_TYPE in mariadb postgresql; do
    echo $'\n*************** '"$DB_TYPE: connectivity" >&2
    t3_ run -D $DB_TYPE -P $HOST_IP:$DB_PORT

    echo "Pinging $DB_TYPE" >&2
    case $DB_TYPE in
        mariadb)
            verify_cmd_success $SUCCESS_TIMEOUT mysql -h $HOST_IP -P $DB_PORT -D t3 -u t3 --password=t3 -e 'quit' t3
            verify_logs $SUCCESS_TIMEOUT 'mysqld: ready for connections'
            ;;

        postgresql)
            verify_cmd_success $SUCCESS_TIMEOUT pg_isready -h $HOST_IP -p $DB_PORT -d t3 -U t3 -q
            verify_logs $SUCCESS_TIMEOUT 'ready to accept connections'
            ;;
    esac

    cleanup
done

DB_NAME=bar
DB_USER=foo
DB_PW=123456

for DB_TYPE in mariadb postgresql; do
    echo $'\n*************** '"$DB_TYPE: custom credentials" >&2
    T3_DB_NAME=$DB_NAME T3_DB_USER=$DB_USER T3_DB_PW=$DB_PW t3_ run -D $DB_TYPE -P $HOST_IP:$DB_PORT

    echo "Pinging $DB_TYPE" >&2
    case $DB_TYPE in
        mariadb)
            verify_cmd_success $SUCCESS_TIMEOUT mysql -h $HOST_IP -P $DB_PORT -D $DB_NAME -u $DB_USER --password=$DB_PW -e 'quit' $DB_NAME
            verify_logs $SUCCESS_TIMEOUT 'mysqld: ready for connections'
            ;;

        postgresql)
            verify_cmd_success $SUCCESS_TIMEOUT pg_isready -h $HOST_IP -p $DB_PORT -d $DB_NAME -U $DB_USER -q
            verify_logs $SUCCESS_TIMEOUT 'ready to accept connections'
            ;;
    esac

    cleanup
done


# Test custom container name and hostname
CONT_NAME=foo
HOST_NAME=dev.under.test

echo $'\n*************** Custom container name and hostname' >&2
t3_ run
test "$(docker exec typo3 hostname)" = typo3.${HOSTNAME}
cleanup

T3_NAME=$CONT_NAME t3_ run -H $HOST_NAME
test "$(docker exec $CONT_NAME hostname)" = $HOST_NAME
t3_ stop -n $CONT_NAME --rm
docker volume prune --force >/dev/null


# Test volume names, working directories and ownership
ROOT_VOL='./root-volume/root'
DB_VOL="$(readlink -f .)/database volume/dbdata"
echo $'\n*************** Volume names, working directories and ownership' >&2

echo 'Testing volume names' >&2
T3_ROOT=$(basename "$ROOT_VOL") t3_ run -V $(basename "$DB_VOL")
verify_volumes_exist $(basename "$ROOT_VOL") $(basename "$DB_VOL")

cleanup

echo 'Testing working directories' >&2
T3_DB_DATA="$DB_VOL" t3_ run -v "$ROOT_VOL" -D postgresql

verify_cmd_success $SUCCESS_TIMEOUT sudo test -f "$ROOT_VOL/public/FIRST_INSTALL"
! sudo test -O "$ROOT_VOL/public/FIRST_INSTALL"
! sudo test -G "$ROOT_VOL/public/FIRST_INSTALL"

verify_cmd_success $SUCCESS_TIMEOUT sudo test -f "$DB_VOL/PG_VERSION"
! sudo test -O "$DB_VOL/PG_VERSION"
! sudo test -G "$DB_VOL/PG_VERSION"

cleanup
sudo rm -rf "$ROOT_VOL" "$DB_VOL"

echo 'Testing working directory ownership' >&2
t3_ run -v "$ROOT_VOL" -o -V "$DB_VOL" -O -D postgresql

verify_cmd_success $SUCCESS_TIMEOUT test -f "$ROOT_VOL/public/FIRST_INSTALL"
test -O "$ROOT_VOL/public/FIRST_INSTALL"
test -G "$ROOT_VOL/public/FIRST_INSTALL"

verify_cmd_success $SUCCESS_TIMEOUT test -f "$DB_VOL/PG_VERSION"
test -O "$DB_VOL/PG_VERSION"
test -G "$DB_VOL/PG_VERSION"

cleanup
rm -rf "$ROOT_VOL" "$DB_VOL"


# Test Composer Mode
echo $'\n*************** Composer Mode' >&2
t3_ run
verify_logs $SUCCESS_TIMEOUT 'Extension Manager'
! verify_cmd_success $FAILURE_TIMEOUT t3_ composer show
cleanup

t3_ run -c
verify_logs $SUCCESS_TIMEOUT 'Composer Mode'
verify_cmd_success $SUCCESS_TIMEOUT t3_ composer show | grep -q -F 'typo3/cms-'
cleanup


# Test container environment settings
echo $'\n*************** Container environment settings' >&2
echo "Verifying timezone and language" >&2
LOCALE=de_AT.UTF-8
TZ=Australia/Melbourne
TEMP_FILE=$(mktemp)

T3_LANG=$LOCALE t3_ run --env TIMEZONE=$TZ 
verify_logs $SUCCESS_TIMEOUT $LOCALE
verify_logs $SUCCESS_TIMEOUT $TZ

cleanup

echo "Verifying developer mode" >&2
t3_ run --env MODE=dev
verify_logs $SUCCESS_TIMEOUT 'developer mode'

echo "Verifying MODE check" >&2
t3_ env MODE=abc 2>&1 | grep -q -F 'Unknown mode'

cleanup

echo "Verifying mode changes and abbreviations" >&2
T3_MODE=d t3_ run
verify_logs $SUCCESS_TIMEOUT 'developer mode'
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $INSTALL_URL >$TEMP_FILE
grep -q '^Server: Apache/.* PHP/.* OpenSSL/.*$' $TEMP_FILE && grep -q '^X-Powered-By: PHP/.*$' $TEMP_FILE

t3_ env MODE=pr | grep -q -F 'production mode'
verify_cmd_success $FAILURE_TIMEOUT curl -Is $INSTALL_URL >$TEMP_FILE
! grep -q '^Server: Apache/' $TEMP_FILE && ! grep -q '^X-Powered-By:' $TEMP_FILE

echo "Verifying developer mode with XDebug" >&2
t3_ env MODE=x | grep -q -F 'developer mode with XDebug'
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $INSTALL_URL >$TEMP_FILE
grep -q '^Server: Apache/.* PHP/.* OpenSSL/.*$' $TEMP_FILE && grep -q '^X-Powered-By: PHP/.*$' $TEMP_FILE

echo "Verifying MODE persistence" >&2
t3_ env PHP_foo=bar | grep -q -F 'developer mode with XDebug'

echo "Verifying php.ini setting" >&2
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 cat /etc/php7/conf.d/zz_99_overrides.ini | grep -q -F 'foo="bar"'

echo "Verifying settings precedence" >&2
T3_MODE=dev PHP_foo=xyz t3_ env MODE=x PHP_foo=bar | grep -q -F 'developer mode with XDebug'
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 cat /etc/php7/conf.d/zz_99_overrides.ini | grep -q -F 'foo="bar"'

cleanup

t3_ run -c
sleep $SUCCESS_TIMEOUT    # for TYPO3 8.7, MariaDB startup will take that long

echo "Verifying that COMPOSER_EXCLUDE was set"
EXCLUDED=public/typo3/sysext/core:public/typo3/sysext/setup

t3_ env COMPOSER_EXCLUDE=$EXCLUDED >$TEMP_FILE
IFS=: read -ra DIRS <<< "$EXCLUDED"
for D in "${DIRS[@]}"; do
    grep -q -F "$D" $TEMP_FILE
done

echo "Verifying that COMPOSER_EXCLUDE is being excluded"
t3_ composer update >$TEMP_FILE
IFS=: read -ra DIRS <<< "$EXCLUDED"
for D in "${DIRS[@]}"; do
    grep -q -F "Saved '$D'" $TEMP_FILE
    grep -q -F "Restored '$D'" $TEMP_FILE
done

cleanup

echo "Verifying that COMPOSER_EXCLUDE was set"
EXCLUDED=public/typo3/sysext/core:public/typo3/sysext/setup

# Test certificates
HOST_NAME=dev.under.test
CERTFILE='cert file'
CN=foo.bar

echo $'\n*************** Self-signed certificate' >&2
t3_ run -H $HOST_NAME
verify_logs $SUCCESS_TIMEOUT "CN=$HOST_NAME"
cleanup

echo $'\n*************** Custom certificate' >&2
openssl genrsa -out "$CERTFILE.key" 3072 2>/dev/null
openssl req -new -sha256 -out "$CERTFILE.csr" -key "$CERTFILE.key" -subj "/CN=$CN" 2>/dev/null
openssl x509 -req -days 1 -in "$CERTFILE.csr" -signkey "$CERTFILE.key" -out "$CERTFILE.pem" -outform PEM 2>/dev/null

t3_ run -k "$CERTFILE.key,$CERTFILE.pem"

echo "Waiting for certificate" >&2
verify_cmd_success $SUCCESS_TIMEOUT curl -Isk $INSTALL_URL_SECURE | grep -q '200 OK'
echo | \
    openssl s_client -showcerts -servername -connect $HOST_IP:$HTTPS_PORT 2>/dev/null | \
        grep -q -F "subject=CN = $CN"
cleanup


# Remove trap
trap - EXIT

# If we have arrived here then exit successfully
exit 0
