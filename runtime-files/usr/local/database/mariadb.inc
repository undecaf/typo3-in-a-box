#!/bin/bash

#
# Sets up MariaDB with the requested configuration
# ================================================
#
# Usage: source THIS_FILE
#
# Requires: source /usr/local/lib/utils.inc
#           source /usr/local/lib/env.inc
#

# Set up $MYSQL_DATA as a volume (bind-mounted or unbound)
setup_volume $MYSQL_DATA $MYSQL_USER "$T3_DB_OWNER"
chmod 700 $MYSQL_DATA

mkdir -p $MYSQL_RUN
chown -R $MYSQL_USER: $MYSQL_RUN

# Initialize MariaDB if necessary
if [ ! -d $MYSQL_DATA/mysql ]; then
    log_info 'Initializing MariaDB'

    # Initialize MariaDB and suppress the sermon following the first blank line
    mysql_install_db \
        --user=$MYSQL_USER \
        --datadir=$MYSQL_DATA \
        2>/dev/null \
        | awk '/^[[:blank:]]*$/ { bl = 1 } !bl { print }' | log_info

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

SERVICE_DIR=/etc/services.d/30-mariadb
mkdir -p $SERVICE_DIR

# Let s6 start MariaDB as a service,
# preprocess the error log and send it to syslog-ng
cat >$SERVICE_DIR/run <<EOT
#!/bin/bash

set -e

FACILITY=18   # local2

PRIO_NOTICE=\$((FACILITY*16+5))
PRIO_WARN=\$((FACILITY*16+4))
PRIO_ERROR=\$((FACILITY*16+3))
PRIO_INFO=\$((FACILITY*16+6))

# Ignores the timestamp, saves optional severity and message
RE='^[[:digit:] :-]*(\\[([^\\[]+)])?[[:space:]]*(.*)\$'

# Preprocesses MySQL log messages for syslog-ng
preprocess() {
    local PRIO
    local MSG
    local PROG="mysqld[\$(pidof mysqld)]"

    while IFS= read -r; do
        if [[ "\$REPLY" =~ \$RE ]]; then
            # Extract message
            MSG=\${BASH_REMATCH[3]}

            # Convert optional MySQL severity to a syslog priority
            shopt -s nocasematch
            case "\${BASH_REMATCH[2]}" in
                not*)
                    PRIO=\$PRIO_NOTICE
                    ;;
                warn*)
                    PRIO=\$PRIO_WARN
                    ;;
                err*)
                    PRIO=\$PRIO_ERROR
                    ;;
                *)
                    PRIO=\$PRIO_INFO
                    ;;
            esac

            echo "<\$PRIO> \$PROG: \$MSG" >>$MYSQL_LOGS/error
        fi
    done
}

# FIFO passing preprocessed log messages to syslog-ng
mkdir -p $MYSQL_LOGS
mkfifo $MYSQL_LOGS/error
chown -R ${MYSQL_USER}: $MYSQL_LOGS

# Start MariaDB
exec $(which s6-envdir) ${ENV_DIR} \
    $(which mysqld) \
        --datadir=$MYSQL_DATA \
        --user=$MYSQL_USER \
        --log-warnings=2 \
        --verbose=0 \
        --skip-networking=0 \
        2>&1 | preprocess
EOT

chmod 755 $SERVICE_DIR/run
