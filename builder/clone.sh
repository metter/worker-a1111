#!/bin/bash

set -Eeuox pipefail

mkdir -p /repositories/"$1"
cd /repositories/"$1"
git init
git remote add origin "$2"
git fetch origin HEAD --depth=1   # fetch the latest commit from the default branch
git reset --hard FETCH_HEAD       # reset to the latest fetched commit
rm -rf .git
