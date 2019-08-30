#!/bin/bash

TEMP_TAG=$TRAVIS_REPO_SLUG:$TYPO3_VER-dev

echo $'\n*************** '"Pushing $TEMP_TAG"
docker push $TEMP_TAG
