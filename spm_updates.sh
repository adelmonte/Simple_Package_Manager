#!/bin/bash
CACHE_FILE="/var/cache/spm/update-cache.txt"
DETAILED_CACHE_FILE="/var/cache/spm/detailed-update-cache.txt"
PACKAGE_LIST_CACHE="/var/cache/spm/package-list-cache.txt"

mkdir -p "$(dirname "$CACHE_FILE")"

pacman -Sy > /dev/null 2>&1

updates=$(pacman -Qu 2>/dev/null | grep -v '\[ignored\]' | wc -l)

echo "$updates" > "$CACHE_FILE"

if [ "$updates" -gt 0 ]; then
    pacman -Qu 2>/dev/null | grep -v '\[ignored\]' > "$DETAILED_CACHE_FILE"
else
    echo "No updates available." > "$DETAILED_CACHE_FILE"
fi

echo "Regenerating package list cache..."
repo_order=$(grep '^\[.*\]' /etc/pacman.conf | grep -v '^\[options\]' | sed 's/[][]//g')
installed_packages=$(pacman -Qq 2>/dev/null)

yay -Sl 2>&1 | grep -v "error:" | awk -v repo_order="$repo_order" -v installed="$installed_packages" '
BEGIN {
    split(repo_order, repos)
    for (i in repos) {
        repo_priority[repos[i]] = i
    }
    split(installed, inst_arr)
    for (pkg in inst_arr) {
        is_installed[inst_arr[pkg]] = 1
    }
}
{
    repo = $1
    package = $2
    version = $3
    if (version == "" || version == "unknown") {
        version = "unknown"
    }
    priority = (repo in repo_priority) ? repo_priority[repo] : (repo == "aur" ? 998 : 999)
    installed_priority = (package in is_installed) ? 0 : 1
    status = (package in is_installed) ? "[INSTALLED]" : ""
    
    # Store data with delimiter for column processing
    if (repo == "aur") {
        printf "%01d %03d %s|%s|%s\n", installed_priority, priority, package, repo, status
    } else {
        printf "%01d %03d %s %s|%s|%s\n", installed_priority, priority, package, version, repo, status
    }
}' | sort -n | cut -d' ' -f3- | column -t -s'|' > "$PACKAGE_LIST_CACHE"

echo "Updates found: $updates"
echo "Package list cache updated"
exit 0