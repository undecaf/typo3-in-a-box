#!/bin/bash

# Set environment variables for the current job
source .travis/setenv.inc
export T3_ENGINE=${T3_ENGINE:-podman}

echo $'\n*************** '"Building image for tags: $DEPLOY_TAGS"

set -x

$T3_ENGINE build \
    --build-arg BUILD_DATE=$(date --utc +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg COMMIT=$TRAVIS_COMMIT \
    --build-arg TYPO3_VER=$TYPO3_VER \
    --build-arg PRIMARY_TAG=$PRIMARY_TAG \
    --build-arg DEPLOY_TAGS="$DEPLOY_TAGS" \
    --tag $PRIMARY_IMG \
    "$@" \
    .
