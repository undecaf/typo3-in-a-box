#
# Runtime environment utils
# =========================
#
# Usage: source THIS_FILE
#

# Runtime environment saved here
ENV_DIR=/var/run/s6/container_environment

# Container environment variables that can be changed by 't3 env'
RE_CONT_ENV_VARS='MODE|COMPOSER_EXCLUDE|PHP_[^=]+'


# --------------------------------------------------------------------------

# Sets a variable of the runtime environment.
#
# Arguments:
#   $1  variable name
#   $2  variable value
#
set_var() {
    /bin/mkdir -p ${ENV_DIR}
    echo "$2" >${ENV_DIR}/$1
}


# --------------------------------------------------------------------------

# Replaces the runtime environment with the specified NAME=VALUE pairs,
# removing the leading 'T3_' from container environment variable names.
#
# Arguments:
#   $1, $2, ...  NAME=VALUE pairs
#
set_env() {
    local RE_CONT_ENV='^(T3_('${RE_CONT_ENV_VARS}'))=(.*)$'
    local RE_OTHER_ENV='^([^=]+)=(.*)$'
    local PAIR

    /bin/mkdir -p ${ENV_DIR}
    /bin/rm -f ${ENV_DIR}/*

    for PAIR; do
        if [[ $PAIR =~ ${RE_CONT_ENV} ]]; then
            echo "${BASH_REMATCH[3]}" >${ENV_DIR}/${BASH_REMATCH[2]}
        elif [[ $PAIR =~ ${RE_OTHER_ENV} ]]; then
            echo "${BASH_REMATCH[2]}" >${ENV_DIR}/${BASH_REMATCH[1]}
        fi
    done
}


# --------------------------------------------------------------------------

# Exports the saved runtime environment variables into the current script.
#
load_env() {
    # Elegant but outputs several extra 'declare -x ...' to stdout which I am unable to suppress
    # . <(/bin/s6-envdir ${ENV_DIR} /bin/sh -c 'export')

    # Clumsy but working
    for NAME in ${ENV_DIR}/*; do
        if [ -f "${NAME}" ]; then
            export $(basename ${NAME})="$(< ${NAME})"
        fi
    done
}
