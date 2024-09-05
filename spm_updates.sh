#!/bin/bash

CACHE_FILE="/var/cache/spm/update-cache.txt"

# Ensure the cache directory exists
mkdir -p "$(dirname "$CACHE_FILE")"

# Sync databases
pacman -Sy > /dev/null

# Check for updates, excluding ignored packages
updates=$(pacman -Qu | grep -v '\[ignored\]' | wc -l)

# Write the update count to the cache file
echo "$updates" > "$CACHE_FILE"

echo "Updates found: $updates"
echo "Cache file content: $(cat "$CACHE_FILE")"

exit 0
