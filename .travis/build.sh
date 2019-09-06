#!/bin/bash

# Set environment variables for the current job
source .travis/setenv.inc

echo $'\n*************** '"Building image for tags: $DEPLOY_TAGS"

set -x

docker build \
    --build-arg BUILD_DATE=$(date --utc +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg COMMIT=$TRAVIS_COMMIT \
    --build-arg TYPO3_VER=$TYPO3_VER \
    --build-arg PRIMARY_TAG=$PRIMARY_TAG \
    --build-arg DEPLOY_TAGS="$DEPLOY_TAGS" \
    --tag $PRIMARY_IMG \
    .
