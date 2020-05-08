#
# Runtime initialization utils
# ============================
#
# Usage: source THIS_FILE
#

# Logs a message to stdout in the same format as s6 would.
#
# Arguments:
#   $1   optional message; if omitted then the message is
#        obtained from stdin
#
log() {
    if [ -n "$1" ]; then
        echo "$1" | log
    else
        local S6_LOG_HEADER='['"$(basename $(dirname $0))"']'" $(basename $0):"
        awk '{ print "'"$S6_LOG_HEADER"'", $0 }'
    fi
}


# --------------------------------------------------------------------------

# Logs a message to stderr and exits with the specified return status
# (or with 1).
#
# Calls:
#   log
#
err_exit() {
    log "$1" >&2
    exit ${2:-1}
}


# --------------------------------------------------------------------------

# Returns success if this container is a Podman container.
#
is_podman_container() {
    cat /proc/self/mounts | grep -q -F '/run/.containerenv'
}


# --------------------------------------------------------------------------

# Sets up a directory as a bind-mounted or an unbound volume. At the host, 
# makes the current user appear as the volume owner if so required; inside
# the container, makes the specified user the volume owner.
#
# Arguments:
#   $1  volume path
#   $2  name of user (and group) that should appear as volume owner inside the
#       container
#   $3  (optional) if non-empty then the current host user should appear
#       as the owner of a bind-mounted volume at the host
#   $4  (optional) .tar.gz file to unpack in the volume
#
# Environment:
#   UNBOUND_MARKER    basename of marker file placed in yet unbound volumes
#
# Calls:
#   log
#   is_podman_container
#
setup_volume() {
    local OWNER=$2

    # First 't3 run' of a new TYPO3 instance, and no owner mapping requested?
    # TODO Use this branch also if a Docker container Desktop for Windows or macOS
    if [ -f $1/$UNBOUND_MARKER -a -z "$3" ]; then
        log "Setting up $1"

        # Unpack $4 if specified
        mkdir -p $1
        if [ -f "$4" ]; then
            log "Unpacking $4 into $1"
            tar -xzf $4 -C $1
        fi

        # Set the volume owner
        chown -R $OWNER: $1

    # First run of a new TYPO3 instance, and a bind-mounted volume?
    elif [ ! -d $1 -o -z "$(ls -A $1 2>/dev/null)" ]; then
        # Owner mapping requested?
        if [ -n "$3" ]; then
            # Which type of container engine?
            if is_podman_container; then
                # For Podman in rootless mode, make root the volume owner;
                # such a volume appears at the host as being owned by the current user.
                # Use bindfs later to make $2 appear as the volume owner inside this container
                log "Setting up $1 as bind-mounted volume for the current Podman user"
                OWNER=root

            else
                # For Docker, set UID and GID of $2 equal to the UID and GID
                # of the current owner of $1
                log "Setting up $1 as bind-mounted volume for the current owner"
                usermod -u $(stat -c '%u' $1) -o $2
                groupmod -g $(stat -c '%g' $1) -o $2
            fi

        else
            # Bind-mounted volume without owner mapping
            log "Setting up $1 as bind-mounted volume"
        fi

        # Unpack $4 if specified
        mkdir -p $1
        if [ -f "$4" ]; then
            log "Unpacking $4 into $1 (this could take some time)"
            tar -xzf $4 -C $1
        fi

        # Set the volume owner
        chown -R $OWNER: $1

    # Subsequent 't3 run', directory already populated
    else
        # Owner mapping requested, and a Docker container?
        if [ -n "$3" ] && ! is_podman_container; then
            # Set UID and GID of $2 equal to the UID and GID of the current owner of $1
            usermod -u $(stat -c '%u' $1) -o $2
            groupmod -g $(stat -c '%g' $1) -o $2
        fi

        log "$1 is already populated, owner: $(stat -c '%U' $1)"
    fi

    # Remove the marker
    rm -f $1/$UNBOUND_MARKER

    # In Podman containers, if directory $1 does not have
    # the required owner then bind-mount it to itself
    if is_podman_container && [ "$(stat -c '%U' $1)" != "$2" ]; then
        # Make $2 appear as the volume owner _inside the container_
        # and ignore subsequent chowns and chgrps
        bindfs \
            --force-user=$2 --force-group=$2 \
            --create-for-user=root --create-for-group=root \
            --chown-ignore --chgrp-ignore \
            --multithreaded \
            $1 $1
    fi
}
