#!/bin/zsh

# Install Docker mockup
mkdir -p /usr/local/bin
cp .travis/test/docker-mock.sh /usr/local/bin/docker

# Test error handling
. .travis/test/errors
