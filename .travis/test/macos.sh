#!/bin/zsh

# Install Docker mockup
mkdir -p /usr/local/bin
cp .travis/test/docker-mock.sh /usr/local/bin/docker

# Use zsh for t3 script since bash is outdated
sed -e 's_#!/bin/bash_#!/bin/zsh_' -i .bak t3

docker run alpine:latest /bin/sh -c "echo 'Hello world'"
