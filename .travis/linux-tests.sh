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
    docker container inspect "$@" &>/dev/null \
        || { echo "verify_containers_exist failed: $@" >&2; return 1; }
}

# Returns success if all specified containers are running.
verify_containers_running() {
    echo "verify_containers_running: $@" >&2
    ! docker container inspect --format='{{.State.Status}}' "$@" | grep -v -q 'running' \
        || { echo "verify_containers_running failed: $@" >&2; return 1; }
}

# Returns success if all specified volumes exist.
verify_volumes_exist() {
    echo "verify_volumes_exist: $@" >&2
    docker volume inspect "$@" &>/dev/null \
        || { echo "verify_volumes_exist failed: $@" >&2; return 1; }
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
        test $T -gt 0 \
            || { echo "verify_cmd_success failed: $@" >&2; return 1; }
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
        test $T -gt 0 || { echo "verify_logs failed: '$2'" >&2; return 1; }
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
if [[ "$TYPO3_VER" =~ $RE ]]; then
    export TYPO3_V8=true
    export T3_DB_TYPE=postgres
else
    export TYPO3_V8=
    export T3_DB_TYPE=
fi

# TYPO3 installation URLs
HOST_IP=127.0.0.1
HTTP_PORT=8080
HTTPS_PORT=8443
DB_PORT=3000
INSTALL_URL=http://$HOST_IP:$HTTP_PORT/typo3/install.php
INSTALL_URL_SECURE=https://$HOST_IP:$HTTPS_PORT/typo3/install.php
SYNTAX_ERR_URL=http://$HOST_IP:$HTTP_PORT/syntax-err.php
RUNTIME_ERR_URL=http://$HOST_IP:$HTTP_PORT/runtime-err.php

# Timeouts in s
SUCCESS_TIMEOUT=30
FAILURE_TIMEOUT=5

# Used to capture output
TEMP_FILE=$(mktemp)


echo $'\n*************** Testing '"TYPO3 v$TYPO3_VER, image $PRIMARY_IMG" >&2

# Clean up Docker on exit
trap 'set +e; cleanup;' EXIT

# Exit with error status if any verification fails
set -e


# Test help and error handling
source .travis/messages.inc


# Test basic container and volume status
echo $'\n*************** Basic container and volume status' >&2

echo "Verifying running container and existing volumes"
t3_ run
verify_containers_running typo3
verify_volumes_exist typo3-root typo3-data

verify_error 'Cannot run container' ./t3 run

t3_ stop
verify_containers_exist typo3
! verify_containers_running typo3
verify_volumes_exist typo3-root typo3-data

cleanup

echo "Verifying removed container and retained volumes"
t3_ run

t3_ stop --rm
! verify_containers_exist typo3
verify_volumes_exist typo3-root typo3-data

docker volume prune --force >/dev/null

echo "Verifying t3 argument passthrough"
t3_ run --label foo=bar
test "$(docker inspect --format '{{.Config.Labels.foo}}' typo3)" = 'bar'

cleanup

t3_ run -- --label foo=bar
test "$(docker inspect --format '{{.Config.Labels.foo}}' typo3)" = 'bar'

cleanup


# Test logging
echo $'\n*************** Logging' >&2

echo "Verifying TYPO3 version and log output"
t3_ run
verify_logs $SUCCESS_TIMEOUT ' Apache/TYPO3'
verify_logs $SUCCESS_TIMEOUT " TYPO3 $TYPO3_VER"
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


# Test PHP error logging
echo $'\n*************** PHP error logging' >&2

t3_ run
verify_logs $SUCCESS_TIMEOUT 'AH00094'
docker cp .travis/$(basename $SYNTAX_ERR_URL) typo3:/var/www/localhost/public/
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $SYNTAX_ERR_URL | grep -q '500 Internal Server Error'
verify_logs $SUCCESS_TIMEOUT 'syntax error'

docker cp .travis/$(basename $RUNTIME_ERR_URL) typo3:/var/www/localhost/public/
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $RUNTIME_ERR_URL | grep -q '200 OK'
verify_logs $SUCCESS_TIMEOUT 'Undefined variable'

cleanup


# Test databases
for DB_TYPE in mariadb postgresql; do
    echo $'\n*************** '"$DB_TYPE: connectivity" >&2
    t3_ run -D $DB_TYPE -P $HOST_IP:$DB_PORT

    echo "Pinging $DB_TYPE" >&2
    case $DB_TYPE in
        mariadb)
            verify_logs $SUCCESS_TIMEOUT 'ready for connections'
            verify_cmd_success $SUCCESS_TIMEOUT mysql -h $HOST_IP -P $DB_PORT -D t3 -u t3 --password=t3 -e 'quit' t3
            ;;

        postgresql)
            verify_logs $SUCCESS_TIMEOUT 'ready to accept connections'
            verify_cmd_success $SUCCESS_TIMEOUT pg_isready -h $HOST_IP -p $DB_PORT -d t3 -U t3 -q
            ;;
    esac

    cleanup
done

DB_NAME=bar
DB_USER=foo
DB_PW=123456
DB_LANG=es

for DB_TYPE in mariadb postgresql; do
    echo $'\n*************** '"$DB_TYPE: custom credentials and collation" >&2
    T3_DB_NAME=$DB_NAME T3_DB_USER=$DB_USER T3_DB_PW=$DB_PW t3_ run -D $DB_TYPE -P $HOST_IP:$DB_PORT --env LANG=$DB_LANG

    echo "Pinging $DB_TYPE" >&2
    case $DB_TYPE in
        mariadb)
            verify_logs $SUCCESS_TIMEOUT 'ready for connections'
            verify_logs $SUCCESS_TIMEOUT 'utf8_spanish2_ci'
            verify_cmd_success $SUCCESS_TIMEOUT mysql -h $HOST_IP -P $DB_PORT -D $DB_NAME -u $DB_USER --password=$DB_PW -e 'quit' $DB_NAME
            ;;

        postgresql)
            verify_logs $SUCCESS_TIMEOUT 'ready to accept connections'
            verify_logs $SUCCESS_TIMEOUT 'spanish'
            verify_cmd_success $SUCCESS_TIMEOUT pg_isready -h $HOST_IP -p $DB_PORT -d $DB_NAME -U $DB_USER -q
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
echo $'\n*************** Volume names, bind mounts and ownership, and volume persistence' >&2

echo 'Testing volume names and persistence' >&2
T3_ROOT=$(basename "$ROOT_VOL") t3_ run -V $(basename "$DB_VOL")
verify_volumes_exist $(basename "$ROOT_VOL") $(basename "$DB_VOL")
verify_logs $SUCCESS_TIMEOUT 'SSL certificate'
FINGERPRINT="$(docker exec typo3 openssl x509 -noout -in /var/www/localhost/.ssl/server.pem -fingerprint -sha256)"

t3_ stop --rm
T3_ROOT=$(basename "$ROOT_VOL") t3_ run -V $(basename "$DB_VOL")
verify_logs $SUCCESS_TIMEOUT 'SSL certificate'
test "$FINGERPRINT" = "$(docker exec typo3 openssl x509 -noout -in /var/www/localhost/.ssl/server.pem -fingerprint -sha256)"

cleanup

echo 'Testing bind-mounted volumes and persistence' >&2
T3_DB_DATA="$DB_VOL" t3_ run -v "$ROOT_VOL" -D postgresql

verify_cmd_success $SUCCESS_TIMEOUT sudo test -f "$ROOT_VOL/public/FIRST_INSTALL"
! sudo test -O "$ROOT_VOL/public/FIRST_INSTALL"
! sudo test -G "$ROOT_VOL/public/FIRST_INSTALL"

verify_cmd_success $SUCCESS_TIMEOUT sudo test -f "$DB_VOL/PG_VERSION"
! sudo test -O "$DB_VOL/PG_VERSION"
! sudo test -G "$DB_VOL/PG_VERSION"

verify_logs $SUCCESS_TIMEOUT 'SSL certificate'
FINGERPRINT="$(sudo openssl x509 -noout -in "$ROOT_VOL/.ssl/server.pem" -fingerprint -sha256)"

t3_ stop --rm
T3_DB_DATA="$DB_VOL" t3_ run -v "$ROOT_VOL" -D postgresql
verify_logs $SUCCESS_TIMEOUT 'SSL certificate'
test "$FINGERPRINT" = "$(sudo openssl x509 -noout -in "$ROOT_VOL/.ssl/server.pem" -fingerprint -sha256)"

cleanup
sudo rm -rf "$ROOT_VOL" "$DB_VOL"

if [ -z "$TYPO3_V8" ]; then
    echo 'Testing interoperability of Apache and SQLite' >&2
    t3_ run -v "$ROOT_VOL" -V "$DB_VOL" -O -D sqlite
    verify_logs $SUCCESS_TIMEOUT 'AH00094'

    t3_ stop --rm
    t3_ run -v "$ROOT_VOL" -V "$DB_VOL" -O -D sqlite
    verify_logs $SUCCESS_TIMEOUT 'AH00094'

    cleanup
    sudo rm -rf "$ROOT_VOL" "$DB_VOL"
fi

echo 'Testing bind-mounted volume ownership and persistence' >&2
t3_ run -v "$ROOT_VOL" -o -V "$DB_VOL" -O -D postgresql

verify_cmd_success $SUCCESS_TIMEOUT test -f "$ROOT_VOL/public/FIRST_INSTALL"
test -O "$ROOT_VOL/public/FIRST_INSTALL"
test -G "$ROOT_VOL/public/FIRST_INSTALL"

verify_cmd_success $SUCCESS_TIMEOUT test -f "$DB_VOL/PG_VERSION"
test -O "$DB_VOL/PG_VERSION"
test -G "$DB_VOL/PG_VERSION"

verify_logs $SUCCESS_TIMEOUT 'SSL certificate'
FINGERPRINT="$(openssl x509 -noout -in "$ROOT_VOL/.ssl/server.pem" -fingerprint -sha256)"

t3_ stop --rm
t3_ run -v "$ROOT_VOL" -o -V "$DB_VOL" -O -D postgresql
verify_logs $SUCCESS_TIMEOUT 'SSL certificate'
test "$FINGERPRINT" = "$(openssl x509 -noout -in "$ROOT_VOL/.ssl/server.pem" -fingerprint -sha256)"

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
verify_cmd_success $SUCCESS_TIMEOUT t3_ composer show | grep -q -F 'typo3/cms-core'
cleanup


# Test container environment settings
echo $'\n*************** Container environment settings' >&2
echo "Verifying timezone and language" >&2
LOCALE=de_AT.UTF-8
TZ=Australia/North  # UTC +09:30, does not have DST
TEMP_FILE=$(mktemp)

T3_LANG=$LOCALE t3_ run --env TIMEZONE=$TZ 
verify_logs $SUCCESS_TIMEOUT $LOCALE
verify_logs $SUCCESS_TIMEOUT $TZ
verify_logs $SUCCESS_TIMEOUT '+09:30 '
cleanup

T3_TIMEZONE=foo t3_ run
verify_logs $SUCCESS_TIMEOUT 'Unsupported timezone'
cleanup


echo "Verifying developer mode" >&2
t3_ run --env MODE=dev
verify_logs $SUCCESS_TIMEOUT 'developer mode'

echo "Verifying MODE check" >&2
! t3_ env --log MODE=abc
verify_logs $SUCCESS_TIMEOUT 'Unknown mode'

cleanup

echo "Verifying mode changes and abbreviations" >&2
T3_MODE=d t3_ run
verify_logs $SUCCESS_TIMEOUT 'developer mode'
verify_logs $SUCCESS_TIMEOUT 'AH00094'
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $INSTALL_URL >$TEMP_FILE
grep -q '^Server: Apache/.* PHP/.* OpenSSL/.*$' $TEMP_FILE && grep -q '^X-Powered-By: PHP/.*$' $TEMP_FILE

t3_ env -l MODE=pr | grep -q -F 'production mode'
verify_cmd_success $FAILURE_TIMEOUT curl -Is $INSTALL_URL >$TEMP_FILE
! grep -q '^Server: Apache/' $TEMP_FILE && ! grep -q '^X-Powered-By:' $TEMP_FILE

echo "Verifying developer mode with XDebug" >&2
t3_ env -l MODE=x | grep -q -F 'developer mode with XDebug'
verify_cmd_success $SUCCESS_TIMEOUT curl -Is $INSTALL_URL >$TEMP_FILE
grep -q '^Server: Apache/.* PHP/.* OpenSSL/.*$' $TEMP_FILE && grep -q '^X-Powered-By: PHP/.*$' $TEMP_FILE

echo "Verifying MODE persistence" >&2
t3_ env -l PHP_foo=bar | grep -q -F 'developer mode with XDebug'

echo "Verifying php.ini setting" >&2
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 cat /etc/php7/conf.d/zz_99_overrides.ini | grep -q -F 'foo="bar"'

echo "Verifying settings precedence" >&2
T3_MODE=dev PHP_foo=xyz t3_ env -l MODE=x PHP_foo=bar | grep -q -F 'developer mode with XDebug'
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 cat /etc/php7/conf.d/zz_99_overrides.ini | grep -q -F 'foo="bar"'

cleanup

t3_ run -c
verify_logs $SUCCESS_TIMEOUT 'AH00094'

echo "Verifying that COMPOSER_EXCLUDE was set"
EXCLUDED=public/typo3/sysext/core:public/typo3/sysext/setup

t3_ env -l COMPOSER_EXCLUDE=$EXCLUDED >$TEMP_FILE
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

echo "Verifying setting, changing and unsetting of arbitrary variables"
t3_ run
verify_logs $SUCCESS_TIMEOUT 'AH00094'

t3_ env A=foo BC=bar DEF=baz
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 /bin/bash -c '. /root/.bashrc; export' | grep -q -F ' A="foo"'
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 /bin/bash -c '. /root/.bashrc; export' | grep -q -F ' BC="bar"'
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 /bin/bash -c '. /root/.bashrc; export' | grep -q -F ' DEF="baz"'

t3_ env A=42 BC= DEF
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 /bin/bash -c '. /root/.bashrc; export' | grep -q -F ' A="42"'
verify_cmd_success $SUCCESS_TIMEOUT docker exec -it typo3 /bin/bash -c '. /root/.bashrc; export' | grep -q -F ' BC=""'
! verify_cmd_success $FAILURE_TIMEOUT docker exec -it typo3 /bin/bash -c '. /root/.bashrc; export' | grep -q -F ' DEF='
cleanup


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
