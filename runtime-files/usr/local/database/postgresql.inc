#!/bin/bash

#
# Sets up PostgreSQL with the requested configuration
# ===================================================
#
# Usage: source THIS_FILE
#
# Requires: source ./utils.inc
#

# Set up $PG_DATA as a volume (bind-mounted or unbound)
setup_volume $PG_DATA $PG_USER "$T3_DB_OWNER"
chmod 700 $PG_DATA

mkdir -p $PG_RUN
chown -R $PG_USER: $PG_RUN

# Initialize PostgreSQL if necessary
if [ ! -f $PG_DATA/PG_VERSION ]; then
    log 'Initializing PostgreSQL'

    # Initialize PostgreSQL
    PWFILE=$(mktemp -u)
    trap "rm -f $PWFILE" EXIT
    echo "$T3_DB_ROOT_PW" >$PWFILE
    su-exec $PG_USER \
    initdb --pgdata=$PG_DATA --auth=md5 --username=$PG_USER --pwfile=$PWFILE | log

    # Create the TYPO3 database unless it is named 'postgres'
    test "$T3_DB_NAME" = postgres || \
        echo "CREATE DATABASE $T3_DB_NAME;" | \
        su-exec $PG_USER \
        postgres --single -D $PG_DATA -j $PG_USER >/dev/null

    # Set the password for the TYPO3 user and grant superuser privileges
    ACTION=CREATE
    test "$T3_DB_USER" = postgres && ACTION=ALTER

    echo "$ACTION USER $T3_DB_USER WITH SUPERUSER PASSWORD '$T3_DB_PW';" | \
        su-exec $PG_USER \
        postgres --single -D $PG_DATA -j $PG_USER >/dev/null

    # Allow external IPv4 and IPv6 connections
    cat >>$PG_DATA/pg_hba.conf <<EOT

host  all  all  0.0.0.0/0  md5
host  all  all  ::0/0      md5
EOT

fi

SERVICE_DIR=/etc/services.d/postgres
mkdir -p $SERVICE_DIR/log

# Have PostgreSQL started as a service by s6
cat >$SERVICE_DIR/run <<EOT
#!/bin/bash

set -e
. /usr/local/lib/env.inc

/bin/s6-envdir ${ENV_DIR} \
    /bin/redirfd -cn 2 /dev/stdout \
    su-exec $PG_USER \
    postgres -D $PG_DATA --listen_addresses='*' --log_line_prefix=''
EOT

# Send all log lines to stdout and save them in $PG_LOGS
cat >$SERVICE_DIR/log/run <<EOT
#!/bin/sh

set -e
. /etc/environment

mkdir -p $PG_LOGS
/bin/s6-log -b \
    n20 s5000000 T $PG_LOGS \
    + T 1
EOT

chmod 755 $SERVICE_DIR/{,log/}run
