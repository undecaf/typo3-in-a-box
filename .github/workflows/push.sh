#!/bin/bash

set -e

# Set environment variables for the current job
source .github/workflows/setenv.inc

echo $'\n*************** '"Deploying $PRIMARY_IMG as $DEPLOY_TAGS"

# Tag primary image with all applicable tags and push them simultaneously
for T in $DEPLOY_TAGS; do 
    docker tag $PRIMARY_IMG $GITHUB_REPOSITORY:$T
done

# Push all local tags
docker login --username undecaf --password "$REGISTRY_PASS"
docker push $GITHUB_REPOSITORY

# Update bages at MicroBadger only for the most recent build version
if [ -n "$MOST_RECENT" ]; then
    curl -X POST https://hooks.microbadger.com/images/$GITHUB_REPOSITORY/$MICROBADGER_WEBHOOK
fi
