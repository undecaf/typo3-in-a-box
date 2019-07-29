#!/bin/bash

source .travis/tags

echo '*************** '"TRAVIS_BRANCH: '$TRAVIS_BRANCH'"
echo '*************** '"TRAVIS_COMMIT: '$TRAVIS_COMMIT'"
echo '*************** '"TRAVIS_TAG: '$TRAVIS_TAG'"
echo '*************** '"TYPO3_VER: '$TYPO3_VER'"
echo '*************** '"IMAGE_VER: '$IMAGE_VER'"
echo '*************** '"TAGS: '$TAGS'"
echo

LOCAL_TAG=localhost/${TRAVIS_REPO_SLUG#*/}

set -x

docker build \
    --pull \
    --cache-from $TRAVIS_REPO_SLUG \
    --build-arg BUILD_DATE=$(date --utc +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg COMMIT=$TRAVIS_COMMIT \
    --build-arg TYPO3_VER=$TYPO3_VER \
    --build-arg IMAGE_VER=$IMAGE_VER \
    --tag $LOCAL_TAG \
    .

set +x

for T in $TAGS; do 
    echo '*************** '"Tagging $LOCAL_TAG as $TRAVIS_REPO_SLUG:$T"
    docker tag $LOCAL_TAG $TRAVIS_REPO_SLUG:$T
done
