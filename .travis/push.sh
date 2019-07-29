#!/bin/bash

source .travis/tags

for T in $TAGS; do 
    echo $'\n*************** '"Pushing $TRAVIS_REPO_SLUG:$T"
    docker push $TRAVIS_REPO_SLUG:$T
done

# README.md exceeds the size limit of Dockerhub, it has to be excerpted manually
exit

echo $'\n*************** Pushing README.md'
docker run --rm \
    -v $(readlink -f README.md):/data/README.md \
    -e DOCKERHUB_USERNAME="$REGISTRY_USER" \
    -e DOCKERHUB_PASSWORD="$REGISTRY_PASS" \
    -e DOCKERHUB_REPO_PREFIX=${TRAVIS_REPO_SLUG%/*} \
    -e DOCKERHUB_REPO_NAME=${TRAVIS_REPO_SLUG#*/} \
    sheogorath/readme-to-dockerhub
