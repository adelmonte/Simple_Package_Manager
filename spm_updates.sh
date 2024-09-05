#!/bin/bash

CACHE_FILE="$HOME/.cache/update-cache.txt"

# Function to check if running as root
is_root() {
    return $(id -u)
}

# Function to run yay as the correct user
run_yay() {
    if is_root; then
        # If root, run yay as the first non-root user with a home directory
        local user=$(grep -E '^[^:]+:[^:]+:[1-9][0-9]{3}' /etc/passwd | cut -d: -f1 | head -n1)
        if [ -n "$user" ]; then
            su - "$user" -c "yay -Qu"
        else
            echo "No suitable non-root user found to run yay" >&2
            return 1
        fi
    else
        # If not root, run yay directly
        yay -Qu
    fi
}

# Run yay and process its output
run_yay | awk '/->/ && !/ignoring package upgrade/ && !/local .* is newer than/ {count++} END {print count ? count : 0}' > "$CACHE_FILE"

# Read the count from the cache file
yay_updates=$(cat "$CACHE_FILE")

# Ensure yay_updates is an integer
if ! [[ "$yay_updates" =~ ^[0-9]+$ ]]; then
    yay_updates=0
fi

# Output for verification
echo "Updates found: $yay_updates"
echo "Cache file content: $(cat "$CACHE_FILE")"

# Exit with the appropriate status
exit 0
