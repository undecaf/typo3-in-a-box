# Sets environment variables for the current job
# ----------------------------------------------
#
# Usage: source $0
#
# Required environment:
#   TRAVIS_REPO_SLUG   undecaf/typo3-in-a-box (required)
#   MAJOR_VER          major version number (required)
#   TRAVIS_BRANCH      master, dev or Git tag (optional)
#   TRAVIS_TAG         Git tag (optional)
#   TRAVIS_COMMIT      commit hash (optional)
#

# Prints the MAJOR.MINOR version of a tag to stdout.
major_minor() {
    local RE    
    RE='^([0-9]+\.[0-9]+)(\..+)?'
    [[ "$1" =~ $RE ]]
    echo ${BASH_REMATCH[1]}
}

# Derive the TYPO3 version to compose from the best matching Composer file name
TYPO3_ROOT=/var/www/localhost

# Find the compose*.json file for $MAJOR_VER (required) and $TRAVIS_BRANCH (optional)
RE1='compose-files'$TYPO3_ROOT'/composer-('$MAJOR_VER'\.[^ \n]+'$TRAVIS_BRANCH')\.json'
RE2='compose-files'$TYPO3_ROOT'/composer-('$MAJOR_VER'\.[^ \n]+)\.json'
if [[ "$(ls compose-files$TYPO3_ROOT/*)" =~ $RE1 ]] || [[ "$(ls compose-files$TYPO3_ROOT/*)" =~ $RE2 ]]; then
    export TYPO3_VER=${BASH_REMATCH[1]}
else
    echo 'Cannot determine TYPO3_VER' >&2
    exit 1;
fi

# Make a list of the tags to which to deploy the tested image
TYPO3_TAG=$(major_minor $TYPO3_VER)
COMMIT_TAG=$(major_minor $TRAVIS_TAG)
test -n "$COMMIT_TAG" && DEPLOY_TAGS=$TYPO3_TAG-$COMMIT_TAG || DEPLOY_TAGS=

# Use branch name, replacing 'master' with 'latest'
case "$TRAVIS_BRANCH" in
    $TRAVIS_TAG|master)
        BRANCH=latest
        DEPLOY_TAGS="$DEPLOY_TAGS ${MOST_RECENT:+$BRANCH}"
        ;;
    *)
        BRANCH=$TRAVIS_BRANCH
        DEPLOY_TAGS="${DEPLOY_TAGS:+$DEPLOY_TAGS-$TRAVIS_BRANCH}"
        ;;
esac

# Most concise tag for this build
export PRIMARY_TAG=$TYPO3_TAG-$BRANCH
export DEPLOY_TAGS=$(echo "$PRIMARY_TAG $DEPLOY_TAGS" | awk '{ $1 = $1; gsub(/ /, ", "); print; }')

# Image-under-test
export PRIMARY_IMG=$TRAVIS_REPO_SLUG:$PRIMARY_TAG


cat <<EOF
+-----------------------------------------------
| TRAVIS_BRANCH: '$TRAVIS_BRANCH'
| TRAVIS_COMMIT: '$TRAVIS_COMMIT'
| TRAVIS_TAG:    '$TRAVIS_TAG'
|
| MAJOR_VER:     '$MAJOR_VER'
| TYPO3_VER:     '$TYPO3_VER'
|
| PRIMARY_IMG:   '$PRIMARY_IMG'
| PRIMARY_TAG:   '$PRIMARY_TAG'
| DEPLOY_TAGS:   '$DEPLOY_TAGS'
+-----------------------------------------------
EOF
