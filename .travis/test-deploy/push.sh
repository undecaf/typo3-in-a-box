#!/bin/bash

# Set environment variables common to all build stages
source .travis/setenv.inc

echo $'\n*************** '"Deploying $TEST_IMG to $DEPLOY_TAGS and cleaning up"

set -x

# Pull image that was built and tested before
docker pull $TEST_IMG

# Tag image with all applicable tags and push them simultaneously
for T in $DEPLOY_TAGS; do 
    docker tag $TEST_IMG $TRAVIS_REPO_SLUG:$T
done

# Untag the local test image so that it doesn not get pushed
docker rmi $TEST_IMG

# Push all local tags
docker push $TRAVIS_REPO_SLUG

# Update bages at MicroBadger
curl -X POST https://hooks.microbadger.com/images/undecaf/typo3-in-a-box/$MICROBADGER_WEBHOOK

# Clean up
.travis/test-deploy/cleanup.sh

exit

# README.md exceeds the size limit of Dockerhub, it has to be excerpted manually
echo $'\n*************** Pushing README.md'
docker run --rm \
    -v $(readlink -f README.md):/data/README.md \
    -e DOCKERHUB_USERNAME="$REGISTRY_USER" \
    -e DOCKERHUB_PASSWORD="$REGISTRY_PASS" \
    -e DOCKERHUB_REPO_PREFIX=${TRAVIS_REPO_SLUG%/*} \
    -e DOCKERHUB_REPO_NAME=${TRAVIS_REPO_SLUG#*/} \
    sheogorath/readme-to-dockerhub
