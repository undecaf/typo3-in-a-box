#
# Sets up SQLite.
#
# Environment:
#   /etc/environment
#
# Calls:
#   init functions
#
start_sqlite() {
    # Set up $SQLITE_DATA as a volume (bind-mounted or unbound)
    setup_volume $SQLITE_DATA $SQLITE_USER "$T3_DB_OWNER"

    # Initialize SQLite if necessary
    SQLITE_LINK=$TYPO3_ROOT/var/sqlite

    if [ ! -d $SQLITE_LINK ]; then
        logger -p $LOG_INFO 'Initializing SQLite'

        # Point the SQLite link at the database volume
        mkdir -p $(dirname $SQLITE_LINK)
        ln -s $SQLITE_DATA $SQLITE_LINK
        chown -R $SQLITE_USER: $(dirname $SQLITE_LINK)
    fi

    logger -p $LOG_INFO 'SQLite ready'
}
