#!/bin/bash

set -Eeuox pipefail

mkdir -p /repositories/"$1"
cd /repositories/"$1"
git init
git remote add origin "$2"
git fetch origin --depth=1
git checkout "$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
rm -rf .git
