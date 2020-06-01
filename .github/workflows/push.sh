#!/bin/bash

# Set environment variables for the current job
source .github/workflows/setenv.inc

echo $'\n*************** '"Deploying $PRIMARY_IMG to $DEPLOY_TAGS"

# Tag primary image with all applicable tags and push them simultaneously
for T in $DEPLOY_TAGS; do 
    docker tag $PRIMARY_IMG $GITHUB_REPOSITORY:$T
done

# Push all local tags
docker login --username undecaf --password "$REGISTRY_PASS"
docker push $TRAVIS_REPO_SLUG

# Update bages at MicroBadger only for the most recent build version
test -n "$MOST_RECENT" \
    && curl -X POST https://hooks.microbadger.com/images/undecaf/typo3-in-a-box/$MICROBADGER_WEBHOOK \
    || true
