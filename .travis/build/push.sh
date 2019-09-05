#!/bin/bash

# Set environment variables common to all build stages
source .travis/setenv.inc

echo $'\n*************** '"Pushing $TEST_IMG"

set -x

docker push $TEST_IMG
