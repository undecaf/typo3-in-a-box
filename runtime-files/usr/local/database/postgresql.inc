#!/bin/bash

#
# Sets up PostgreSQL with the requested configuration
# ===================================================
#
# Usage: source THIS_FILE
#
# Requires: source /usr/local/lib/utils.inc
#           source /usr/local/lib/env.inc
#

# Executes an SQL statement in the PostgreSQL stand-alone backend.
#
# Arguments:
#   $1   SQL statement
#   $2   database name, defaults to $PG_USER if omitted
#
exec_sql() {
    echo "$1" | \
    su-exec $PG_USER \
    postgres \
        --single \
        -D $PG_DATA \
        --log_destination=syslog \
        --syslog_facility=LOCAL2 \
        -j \
        ${2:-$PG_USER}
}


# --------------------------------------------------------------------------

# Set up $PG_DATA as a volume (bind-mounted or unbound)
setup_volume $PG_DATA $PG_USER "$T3_DB_OWNER"
chmod 700 $PG_DATA

mkdir -p $PG_RUN
chown -R $PG_USER: $PG_RUN

# Initialize PostgreSQL if necessary
if [ ! -f $PG_DATA/PG_VERSION ]; then
    # Initialize PostgreSQL
    PWFILE=$(mktemp -u)
    trap "rm -f $PWFILE" EXIT
    echo "$T3_DB_ROOT_PW" >$PWFILE
    su-exec $PG_USER \
    initdb --pgdata=$PG_DATA --auth=md5 --username=$PG_USER --pwfile=$PWFILE | log_info

    # Allow external IPv4 and IPv6 connections
    cat >>$PG_DATA/pg_hba.conf <<EOT

host  all  all  0.0.0.0/0  md5
host  all  all  ::0/0      md5
EOT
fi

# Create the TYPO3 database unless it exists already
exec_sql "SELECT datname FROM pg_database;" | grep -q -F "\"$T3_DB_NAME\"" \
    || exec_sql "CREATE DATABASE $T3_DB_NAME;" >/dev/null

# Create/alter the TYPO3 user, set the password and grant superuser privileges
PATTERN=$RANDOM
ACTION=CREATE
exec_sql "SELECT $PATTERN FROM pg_roles WHERE rolname='$T3_DB_USER'" | grep -q -F $PATTERN \
    && ACTION=ALTER
exec_sql "$ACTION USER $T3_DB_USER WITH SUPERUSER PASSWORD '$T3_DB_PW';" >/dev/null

SERVICE_DIR=/etc/services.d/50-postgres
mkdir -p $SERVICE_DIR

# Let s6 start PostgreSQL as a service
cat >$SERVICE_DIR/run <<EOT
#!/bin/sh

s6-envdir ${ENV_DIR} \
    redirfd -cn 2 /dev/stdout \
    su-exec $PG_USER \
    postgres \
        -D $PG_DATA \
        --log_destination=syslog \
        --log_line_prefix='' \
        --syslog_facility=LOCAL2 \
        --listen_addresses='*' \
        >/dev/null
EOT

chmod 755 $SERVICE_DIR/run
