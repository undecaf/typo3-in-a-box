#!/bin/zsh

VOL_INFO=${TMPDIR}docker-volinfo


case "$1 $2" in
    'create '*|'container create'|'run '*|'container run')
        # Save the volume names and fictional mount points 
        # of the most recent 'docker create' or 'docker run' 
        RE='--volume ([^ ]*/)?([^ /]+):'
        [[ "$@" =~ ${RE}/var/www/localhost ]] && ROOT_VOL=${match[2]} || ROOT_VOL='-'
        [[ "$@" =~ ${RE}/var/lib/typo3-db ]] && DB_VOL=${match[2]} || DB_VOL='-'

        ROOT_MP=$(mktemp -d)
        DB_MP=$(mktemp -d)

        cat >$VOL_INFO <<EOF
ROOT_VOL=$ROOT_VOL
DB_VOL=$DB_VOL
typeset -A MPS
MPS=( $ROOT_VOL $ROOT_MP $DB_VOL $DB_MP )
EOF
        ;;

    'start '*|'container start'|'stop '*|'container stop'|'container rm'|'cp '*|'kill '*)
        # Nothing to do
        ;;

    'container inspect')
        # Echo volume names of most recent 'docker create' or 'docker run'
        . $VOL_INFO
        echo "$ROOT_VOL $DB_VOL"
        ;;

    'volume inspect')
        # Echo the mountpoint of the specified volume
        . $VOL_INFO
        for ARG in "$@"; do :; done
        echo ${MPS[$ARG]}
        ;;

    *)
        echo "++++++++ $0 $@"
        ;;
esac

