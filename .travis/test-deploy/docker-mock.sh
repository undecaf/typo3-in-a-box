#!/bin/zsh

# Prints the last command line argument to stdout.
last_arg() {
    for ARG in "$@"; do :; done
    echo $ARG
}

# Restore state
typeset -A VOL_MP
typeset -A NAME_ROOT
typeset -A NAME_DB

STATE_FILE=${TMPDIR}docker-state
[ -f $STATE_FILE ] && . $STATE_FILE


case "$1 $2" in
    'create '*|'container create'|'run '*|'container run')
        # Return failure if this container already exists
        RE='--name ([^ ]+)'
        [[ "$@" =~ ${RE} ]] && NAME=${match[1]} || NAME='typo3'

        [ -n "${NAME_ROOT[$NAME]}" ] && echo "Container '$NAME' already exists" >&2 && exit 1

        # Save the volume names and fictional mount points for this container
        RE='--volume ([^ ]*/)?([^ /]+):'
        [[ "$@" =~ ${RE}/var/www/localhost ]] && ROOT_VOL=${match[2]} || ROOT_VOL='-'
        [[ "$@" =~ ${RE}/var/lib/typo3-db ]] && DB_VOL=${match[2]} || DB_VOL='-'

        ROOT_MP=$(mktemp -d)
        DB_MP=$(mktemp -d)

        VOL_MP[$ROOT_VOL]=$ROOT_MP
        VOL_MP[$DB_VOL]=$DB_MP
        NAME_ROOT[$NAME]=$ROOT_VOL
        NAME_DB[$NAME]=$DB_VOL

        typeset VOL_MP NAME_ROOT NAME_DB >$STATE_FILE
        ;;

    'start '*|'container start'|'stop '*|'container stop'|'kill '*|'container kill'|'cp '*|'container cp')
        # Nothing to do
        true
        ;;

    'rm '*|'container rm')
        # Remove volume and mountpoint entries
        NAME=$(last_arg "$@")

        unset "VOL_MP[${NAME_ROOT[$NAME]}]"
        unset "VOL_MP[${NAME_DB[$NAME]}]"
        unset "NAME_ROOT[$NAME]"
        unset "NAME_DB[$NAME]"

        typeset VOL_MP NAME_ROOT NAME_DB >$STATE_FILE
        ;;

    'inspect '*|'container inspect')
        # Echo the volume names of this container
        NAME=$(last_arg "$@")

        if [ -n "${NAME_ROOT[$NAME]}" ]; then
            echo "${NAME_ROOT[$NAME]} ${NAME_DB[$NAME]}"
        else
            echo "Container '$NAME' does not exist" >&2
            exit 1
        fi
        ;;

    'volume inspect')
        # Echo the mountpoint of the specified volume
        NAME=$(last_arg "$@")

        echo ${VOL_MP[$NAME]}
        ;;

    'volume prune')
        # Remove all volume and mountpoint information
        VOL_MP=()
        NAME_ROOT=()
        NAME_DB=()

        typeset VOL_MP NAME_ROOT NAME_DB >$STATE_FILE
        ;;

    'reset')
        # Reset state
        rm -rf $STATE_FILE || true
        ;;

    *)
        echo "++++++++ $0 $@"
        ;;
esac

