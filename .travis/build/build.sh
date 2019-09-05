#!/bin/bash

# Set environment variables common to all build stages
source .travis/setenv.inc

echo $'\n*************** '"Building $TEST_IMG"

set -x

docker build \
    --build-arg BUILD_DATE=$(date --utc +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg COMMIT=$TRAVIS_COMMIT \
    --build-arg TYPO3_VER=$TYPO3_VER \
    --build-arg IMAGE_VER=$IMAGE_VER \
    --tag $TEST_IMG \
    .
