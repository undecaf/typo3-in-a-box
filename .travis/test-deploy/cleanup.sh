#!/bin/bash

# Set environment variables common to all build stages
source .travis/setenv.inc

echo $'\n*************** '"Untagging the remote $TEST_IMG"

set -x

curl -u $REGISTRY_USER:$REGISTRY_PASS -X "DELETE" https://cloud.docker.com/v2/repositories/undecaf/typo3-in-a-box/tags/$TEST_TAG/
