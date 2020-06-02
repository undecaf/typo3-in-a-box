#!/bin/bash

cd $GITHUB_WORKSPACE

# Set environment variables for the current job
source .github/workflows/setenv.inc

echo $'\n*************** '"Building $PRIMARY_IMG for tags $DEPLOY_TAGS"

set -x

docker build \
    --build-arg BUILD_DATE=$(date --utc +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg COMMIT=$GITHUB_SHA \
    --build-arg TYPO3_VER=$TYPO3_VER \
    --build-arg PRIMARY_TAG=$PRIMARY_TAG \
    --build-arg DEPLOY_TAGS="$DEPLOY_TAGS" \
    --tag $PRIMARY_IMG \
    "$@" \
    .

docker save --output $IMG_ARTIFACT $PRIMARY_IMG
