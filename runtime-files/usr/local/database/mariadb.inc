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
    # Initialize MariaDB and suppress the sermon following the first blank line
    mysql_install_db \
        --user=$MYSQL_USER \
        --datadir=$MYSQL_DATA \
        2>/dev/null \
        | awk '/^[[:blank:]]*$/ { bl = 1 } !bl { print }' | log_info

    # Find a suitable collation for the current locale
    eval "$(locale)"
    case "$LC_COLLATE" in
        hr*)
            COLLATION=utf8_croatian_ci; ;;
        cz*)
            COLLATION=utf8_czech_ci; ;;
        da*)
            COLLATION=utf8_danish_ci; ;;
        et*)
            COLLATION=utf8_estonian_ci; ;;
        de*)
            COLLATION=utf8_german2_ci; ;;
        hu*)
            COLLATION=utf8_hungarian_ci; ;;
        is*)
            COLLATION=utf8_icelandic_ci; ;;
        lv*)
            COLLATION=utf8_latvian_ci; ;;
        lt*)
            COLLATION=utf8_lithuanian_ci; ;;
        my*)
            COLLATION=utf8_myanmar_ci; ;;
        fa*)
            COLLATION=utf8_persian_ci; ;;
        pl*)
            COLLATION=utf8_polish_ci; ;;
        rm*)
            COLLATION=utf8_roman_ci; ;;
        ro*)
            COLLATION=utf8_romanian_ci; ;;
        si*)
            COLLATION=utf8_sinhala_ci; ;;
        sk*)
            COLLATION=utf8_slovak_ci; ;;
        sl*)
            COLLATION=utf8_slovenian_ci; ;;
        es*)
            COLLATION=utf8_spanish2_ci; ;;
        sv*)
            COLLATION=utf8_swedish_ci; ;;
        tr*)
            COLLATION=utf8_turkish_ci; ;;
        vi*)
            COLLATION=utf8_vietnamese_ci; ;;
        *)
            COLLATION=utf8_general_ci; ;;
    esac
    log_info "Collation for server and database '$T3_DB_NAME': $COLLATION"

    # Create the TYPO3 database and the users
    mysqld \
        --datadir=$MYSQL_DATA \
        --user=$MYSQL_USER \
        --bootstrap \
        --verbose=0 \
        --skip-networking=0 \
        2>/dev/null \
        <<EOT
SET character_set_server = 'utf8';
SET collation_server = '${COLLATION}';
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL ON *.* TO 'root'@'%' identified by '$T3_DB_ROOT_PW' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' identified by '$T3_DB_ROOT_PW' WITH GRANT OPTION;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('$T3_DB_ROOT_PW');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`$T3_DB_NAME\`;
ALTER DATABASE \`$T3_DB_NAME\` CHARACTER SET utf8 COLLATE ${COLLATION};
GRANT ALL ON \`$T3_DB_NAME\`.* TO '$T3_DB_USER'@'%' IDENTIFIED BY '$T3_DB_PW';
GRANT ALL ON \`$T3_DB_NAME\`.* TO '$T3_DB_USER'@'localhost' IDENTIFIED BY '$T3_DB_PW';
EOT
fi

# Receiving end of stdout/stderr from mysqld
mkfifo $MYSQL_LOGS/xfer
chown $MYSQL_USER: $MYSQL_LOGS/xfer

SERVICE_DIR=/etc/services.d/50-mariadb
mkdir -p $SERVICE_DIR/log

# Let s6 start MariaDB as a service
# and send the error log to stdout
cat >$SERVICE_DIR/run <<EOT
#!/bin/sh

exec s6-envdir ${ENV_DIR} \
    mysqld \
        --datadir=$MYSQL_DATA \
        --user=$MYSQL_USER \
        --log-warnings=2 \
        --verbose=0 \
        --skip-networking=0 \
        >>$MYSQL_LOGS/xfer 2>&1
EOT

cat >$SERVICE_DIR/log/run <<EOT
#!/bin/bash

set -e

FACILITY=18   # local2

PRIO_NOTICE=\$((FACILITY*16+5))
PRIO_WARN=\$((FACILITY*16+4))
PRIO_ERROR=\$((FACILITY*16+3))
PRIO_INFO=\$((FACILITY*16+6))

# Ignores the timestamp, groups optional severity and message
RE='^[[:digit:] :-]*(\\[([^\\[]+)])?[[:space:]]*(.*)\$'

MYSQLD_PID=   # will be known at the first log line

# Preprocess MySQL log lines and pass to syslog-ng
shopt -s nocasematch
while IFS= read -r; do
    if [[ "\$REPLY" =~ \$RE ]]; then
        # Get the PID of mysqld at the first log line
        test -n "\$MYSQLD_PID" || MYSQLD_PID=\$(pidof mysqld)

        # Extract the message
        MSG=\${BASH_REMATCH[3]}

        # Convert optional MySQL severity to a syslog priority
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

        echo "<\$PRIO> mysqld[\$MYSQLD_PID]: \$MSG" >>$MYSQL_LOGS/error

    else
        # Unrecognized message format
        echo "<\$PRIO_ERROR> mysqld: Unrecognized log message format: \$REPLY" >>$MYSQL_LOGS/error
    fi
done < $MYSQL_LOGS/xfer
EOT

chmod 755 $SERVICE_DIR/{,log/}run
