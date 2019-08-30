#!/bin/bash

TEMP_TAG=$TRAVIS_REPO_SLUG:$TYPO3_VER-dev

# Extract MAJOR.MINOR of $TRAVIS_TAG
RE='^([0-9]+\.[0-9]+)(\..+)?'
[[ "$TRAVIS_TAG" =~ $RE ]] && TAGS=$TYPO3_VER-${BASH_REMATCH[1]} || TAGS=

# Use branch name, replacing 'master' with 'latest'
case "$TRAVIS_BRANCH" in
    $TRAVIS_TAG|master)
        BRANCH=latest
        IMAGE_VER=$BRANCH
        TAGS="$TAGS $TYPO3_VER-$BRANCH ${MOST_RECENT:+$BRANCH}"
        ;;
    *)
        IMAGE_VER=$TRAVIS_BRANCH
        TAGS="${TAGS:+$TAGS-$TRAVIS_BRANCH} $TYPO3_VER-$TRAVIS_BRANCH"
        ;;
esac

# Pull image that was built before
docker pull $TEMP_TAG

# Tag image with all applicable tags and push them simultaneously
for T in $TAGS; do 
    echo $'\n*************** '"Tagging $TEMP_TAG as $TRAVIS_REPO_SLUG:$T"
    docker tag $TEMP_TAG $TRAVIS_REPO_SLUG:$T
done

echo $'\n*************** '"Pushing all of $TRAVIS_REPO_SLUG"
docker push $TRAVIS_REPO_SLUG

# Update bages at MicroBadger
curl -X POST https://hooks.microbadger.com/images/undecaf/typo3-in-a-box/2UP8UlsdvxENXjuqw_-AerEjcVY=

# README.md exceeds the size limit of Dockerhub, it has to be excerpted manually
exit

echo $'\n*************** Pushing README.md'
docker run --rm \
    -v $(readlink -f README.md):/data/README.md \
    -e DOCKERHUB_USERNAME="$REGISTRY_USER" \
    -e DOCKERHUB_PASSWORD="$REGISTRY_PASS" \
    -e DOCKERHUB_REPO_PREFIX=${TRAVIS_REPO_SLUG%/*} \
    -e DOCKERHUB_REPO_NAME=${TRAVIS_REPO_SLUG#*/} \
    sheogorath/readme-to-dockerhub
