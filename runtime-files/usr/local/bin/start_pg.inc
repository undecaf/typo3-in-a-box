#
# Sets up and starts PostgreSQL with the requested configuration.
#
# Environment:
#   /etc/environment
#
# Calls:
#   init functions
#
start_pg() {
    # Set up $PG_DATA as a volume (bind-mounted or unbound)
    setup_volume $PG_DATA $PG_USER "$T3_DB_OWNER"
    chmod 700 $PG_DATA

    mkdir -p $PG_RUN
    chown -R $PG_USER: $PG_RUN

    # Initialize PostgreSQL if necessary
    if [ ! -f $PG_DATA/PG_VERSION ]; then
        logger -p $LOG_INFO 'Initializing PostgreSQL'

        # Initialize PostgreSQL
        PWFILE=$(mktemp -u)
        trap "rm -f $PWFILE" EXIT
        echo "$T3_DB_ROOT_PW" >$PWFILE
        su-exec $PG_USER initdb --pgdata=$PG_DATA --auth=md5 --username=$PG_USER --pwfile=$PWFILE

        # Create the TYPO3 database unless it is named 'postgres'
        test "$T3_DB_NAME" = postgres || \
            echo "CREATE DATABASE $T3_DB_NAME;" | \
            su-exec $PG_USER postgres --single -D $PG_DATA --log_destination=syslog --syslog_facility=LOCAL2 -j $PG_USER >/dev/null

        # Set the password for the TYPO3 user and grant superuser privileges
        ACTION=CREATE
        test "$T3_DB_USER" = postgres && ACTION=ALTER

        echo "$ACTION USER $T3_DB_USER WITH SUPERUSER PASSWORD '$T3_DB_PW';" | \
            su-exec $PG_USER postgres --single -D $PG_DATA --log_destination=syslog --syslog_facility=LOCAL2 -j $PG_USER >/dev/null

        # Allow external IPv4 and IPv6 connections
        cat <<EOF >>$PG_DATA/pg_hba.conf

host  all  all  0.0.0.0/0  md5
host  all  all  ::0/0      md5
EOF

    fi

    # Start PostgreSQL
    logger -p $LOG_INFO 'Starting PostgreSQL server'
    su-exec $PG_USER postgres -D $PG_DATA --log_destination=syslog --syslog_facility=LOCAL2 --listen_addresses='*' &
}
