#
# Sets up MariaDB with the requested configuration
# ================================================
#
# Usage: source THIS_FILE
#
# Requires: source ./utils.inc
#

# Set up $MYSQL_DATA as a volume (bind-mounted or unbound)
setup_volume $MYSQL_DATA $MYSQL_USER "$T3_DB_OWNER"
chmod 700 $MYSQL_DATA

mkdir -p $MYSQL_RUN
chown -R $MYSQL_USER: $MYSQL_RUN

# Initialize MariaDB if necessary
if [ ! -d $MYSQL_DATA/mysql ]; then
    log 'Initializing MariaDB'

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
        < <(cat <<EOT
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
EOT
            )
fi

# Have MariaDB started as a service by s6
RUN_FILE=/etc/services.d/mariadb/run
mkdir -p $(dirname $RUN_FILE)

cat >$RUN_FILE <<EOT
#!/bin/bash

. /usr/local/lib/env.inc

exec s6-envdir ${ENV_DIR} \
    mysqld \
        --datadir=$MYSQL_DATA \
        --user=$MYSQL_USER \
        --log-warnings=2 \
        --verbose=0 \
        --skip-networking=0 \
        2>&1
EOT

chmod 755 $RUN_FILE
