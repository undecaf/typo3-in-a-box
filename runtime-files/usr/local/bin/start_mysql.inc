#
# Sets up and starts MariaDB with the requested configuration.
#
# Environment:
#   /etc/environment
#
# Calls:
#   init functions
#
start_mysql() {
    # Set up $MYSQL_DATA as a volume (bind-mounted or unbound)
    setup_volume $MYSQL_DATA $MYSQL_USER "$T3_DB_OWNER"

    mkdir -p $MYSQL_RUN
    chown -R $MYSQL_USER: $MYSQL_RUN

    # Initialize MariaDB if necessary
    if [ ! -d $MYSQL_DATA/mysql ]; then
        logger -p $LOG_INFO 'Initializing MariaDB'

        # Initialize MariaDB and suppress the sermon following the first blank line
        mysql_install_db \
            --user=$MYSQL_USER \
            --datadir=$MYSQL_DATA \
            2>/dev/null \
            | awk '/^[[:blank:]]*$/ { bl = 1 } !bl { print }'

        # Create the TYPO3 database and the users
        mysqld \
            --datadir=$MYSQL_DATA \
            --user=$MYSQL_USER \
            --bootstrap \
            --verbose=0 \
            --skip-networking=0 \
            2>/dev/null \
            < <(cat <<EOF
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL ON *.* TO 'root'@'%' identified by '$T3_DB_ROOT_PW' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' identified by '$T3_DB_ROOT_PW' WITH GRANT OPTION;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('$T3_DB_ROOT_PW');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`$T3_DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL ON \`$T3_DB_NAME\`.* TO '$T3_DB_USER'@'%' IDENTIFIED BY '$T3_DB_PW';
GRANT ALL ON \`$T3_DB_NAME\`.* TO '$T3_DB_USER'@'localhost' IDENTIFIED BY '$T3_DB_PW';
EOF
            )
    fi

    # Start MariaDB
    logger -p $LOG_INFO 'Starting MariaDB server'
    mysqld_safe \
        --datadir=$MYSQL_DATA \
        --user=$MYSQL_USER \
        --syslog \
        --verbose=0 \
        --skip-networking=0 \
        >/dev/null &
}
