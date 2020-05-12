#
# Sets up SQLite
# ==============
#
# Usage: source THIS_FILE
#
# Requires: source ./utils.inc
#

# Set up $SQLITE_DATA as a volume (bind-mounted or unbound)
setup_volume $SQLITE_DATA $SQLITE_USER "$T3_DB_OWNER"
chmod 700 $SQLITE_DATA

# Initialize SQLite if necessary
SQLITE_LINK=$TYPO3_ROOT/var/sqlite

if [ ! -d $SQLITE_LINK ]; then
    log 'Initializing SQLite'

    # Point the SQLite link at the database volume
    mkdir -p $(dirname $SQLITE_LINK)
    ln -s $SQLITE_DATA $SQLITE_LINK
    chown -R $SQLITE_USER: $(dirname $SQLITE_LINK)

    log 'OK'
fi
