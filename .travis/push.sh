#!/bin/bash

# Set environment variables for the current job
source .travis/setenv.inc

echo $'\n*************** '"Deploying $PRIMARY_IMG to $DEPLOY_TAGS"

set -x

# Tag primary image with all applicable tags and push them simultaneously
for T in $DEPLOY_TAGS; do 
    docker tag $PRIMARY_IMG $TRAVIS_REPO_SLUG:$T
done

# Push all local tags
docker push $TRAVIS_REPO_SLUG

# Update bages at MicroBadger only for the most recent build version
test -n "$MOST_RECENT" && \
    curl -X POST https://hooks.microbadger.com/images/undecaf/typo3-in-a-box/$MICROBADGER_WEBHOOK

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
