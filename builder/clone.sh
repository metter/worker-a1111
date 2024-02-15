#!/bin/bash

set -euo

# Function to display error and exit
die() {
    echo "$1" >&2
    exit 1
}

# Create directory for repositories
mkdir -p "/repositories/$1" || die "Failed to create directory /repositories/$1"

# Change directory to the repository directory
cd "/repositories/$1" || die "Failed to change directory to /repositories/$1"

# Initialize a new Git repository
git init || die "Failed to initialize Git repository"

# Add remote origin
git remote add origin "$2" || die "Failed to add remote origin $2"

# Fetch from origin with limited depth
git fetch origin "$3" --depth=1 || die "Failed to fetch from $2 with commit $3"

# Reset repository to specified commit
git reset --hard "$3" || die "Failed to reset repository to commit $3"

# Remove the .git directory to cleanup
rm -rf .git || die "Failed to remove .git directory"

echo "Repository $1 cloned successfully!"
