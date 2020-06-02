# Sets environment variables for the current job
# ----------------------------------------------
#
# Usage: source $0
#
# Required environment:
#   GITHUB_REPOSITORY  undecaf/typo3-in-a-box (required)
#   MAJOR_VER          major version number (required)
#   GITHUB_REF         Git tag or Git ref (optional)
#   GITHUB_SHA         commit hash (optional)
#

# Prints the MAJOR.MINOR version of a tag to stdout.
major_minor() {
    local RE    
    RE='^([0-9]+\.[0-9]+)(\..+)?'
    [[ "$1" =~ $RE ]] && echo ${BASH_REMATCH[1]} || echo ''
}

# Derive the TYPO3 version to compose from the best matching Composer file name
TYPO3_ROOT=/var/www/localhost

# Clean up $GITHUB_REF
GITHUB_REF=${GITHUB_REF##*/}

# Find the compose*.json file for $MAJOR_VER (required) and $GITHUB_REF (optional)
RE1='compose-files'$TYPO3_ROOT'/composer-('$MAJOR_VER'\.[^ \n]+'$GITHUB_REF')\.json'
RE2='compose-files'$TYPO3_ROOT'/composer-('$MAJOR_VER'\.[^ \n]+)\.json'
if [[ "$(ls compose-files$TYPO3_ROOT/*)" =~ $RE1 ]] || [[ "$(ls compose-files$TYPO3_ROOT/*)" =~ $RE2 ]]; then
    export TYPO3_VER=${BASH_REMATCH[1]}
else
    echo 'Cannot determine TYPO3_VER' >&2
    exit 1;
fi

# Make a list of the tags to which to deploy the tested image
TYPO3_TAG=$(major_minor $TYPO3_VER)
COMMIT_TAG=$(major_minor $GITHUB_REF)
test -n "$COMMIT_TAG" && DEPLOY_TAGS=$TYPO3_TAG-$COMMIT_TAG || DEPLOY_TAGS=

# Use branch name, replacing 'master' with 'latest'
case "$GITHUB_REF" in
    master)
        BRANCH=latest
        DEPLOY_TAGS="$DEPLOY_TAGS ${MOST_RECENT:+$BRANCH}"
        ;;
    *)
        BRANCH=$GITHUB_REF
        DEPLOY_TAGS="${DEPLOY_TAGS:+$DEPLOY_TAGS-$GITHUB_REF}"
        ;;
esac

# Most concise tag for this build
export PRIMARY_TAG=$TYPO3_TAG-$BRANCH
export DEPLOY_TAGS=$(echo "$PRIMARY_TAG $DEPLOY_TAGS" | awk '{ $1 = $1; gsub(/ /, ", "); print; }')

# Image-under-test
export PRIMARY_IMG=$GITHUB_REPOSITORY:$PRIMARY_TAG
export IMG_ARTIFACT=$GITHUB_WORKSPACE/image-$MAJOR_VER.tar

cat <<EOF
+-----------------------------------------------
| GITHUB_REF:    '$GITHUB_REF'
| GITHUB_SHA:    '$GITHUB_SHA'
|
| MAJOR_VER:     '$MAJOR_VER'
| TYPO3_VER:     '$TYPO3_VER'
|
| PRIMARY_IMG:   '$PRIMARY_IMG'
| PRIMARY_TAG:   '$PRIMARY_TAG'
| DEPLOY_TAGS:   '$DEPLOY_TAGS'
| IMG_ARTIFACT:  '$IMG_ARTIFACT'
+-----------------------------------------------
EOF
