#!/bin/bash
CACHE_FILE="/var/cache/spm/update-cache.txt"
DETAILED_CACHE_FILE="/var/cache/spm/detailed-update-cache.txt"
PACKAGE_LIST_CACHE="/var/cache/spm/package-list-cache.txt"
HEADER_CACHE_FILE="/var/cache/spm/header-cache.txt"
# Private sync DB so checking for updates never syncs the real one (avoids partial upgrades)
SYNC_DB="/var/lib/spm/db"

CACHE_DIR=$(dirname "$CACHE_FILE")
mkdir -p "$CACHE_DIR"
chmod 1777 "$CACHE_DIR" 2>/dev/null

if command -v yay > /dev/null 2>&1; then
    AUR_HELPER="yay"
elif command -v paru > /dev/null 2>&1; then
    AUR_HELPER="paru"
else
    echo "spm_updates: no AUR helper (yay or paru) found" >&2
    exit 1
fi

mkdir -p "$SYNC_DB/sync"
chmod 755 "$(dirname "$SYNC_DB")" "$SYNC_DB" "$SYNC_DB/sync"
ln -sfn /var/lib/pacman/local "$SYNC_DB/local"
cp -pu /var/lib/pacman/sync/*.db "$SYNC_DB/sync/" 2>/dev/null
pacman -Sy --dbpath "$SYNC_DB" --logfile /dev/null > /dev/null 2>&1
sync_status=$?

pending=$(pacman -Qu --dbpath "$SYNC_DB" 2>/dev/null | grep -v '\[ignored\]')
if [ -n "$pending" ]; then
    updates=$(printf '%s\n' "$pending" | wc -l)
else
    updates=0
fi

echo "$updates" > "$CACHE_FILE"

if [ "$updates" -gt 0 ]; then
    printf '%s\n' "$pending" > "$DETAILED_CACHE_FILE"
else
    echo "No updates available." > "$DETAILED_CACHE_FILE"
fi
chmod 666 "$CACHE_FILE" "$DETAILED_CACHE_FILE" 2>/dev/null

repo_order=$(grep '^\[.*\]' /etc/pacman.conf | grep -v '^\[options\]' | sed 's/[][]//g')
installed_packages=$(pacman -Qq 2>/dev/null)

"$AUR_HELPER" -Sl 2>&1 | grep -v "error:" | awk -v repo_order="$repo_order" -v installed="$installed_packages" '
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
chmod 666 "$PACKAGE_LIST_CACHE" 2>/dev/null

packages=$(pacman -Qq | wc -l)
explicit=$(pacman -Qeq | wc -l)
echo "$packages $explicit" > "$HEADER_CACHE_FILE"
chmod 666 "$HEADER_CACHE_FILE" 2>/dev/null

[ "$updates" -eq 1 ] && noun="update" || noun="updates"
if [ "$sync_status" -ne 0 ]; then
    printf 'cache refreshed (sync failed, counts may be stale)\n'
elif [ "$updates" -gt 0 ]; then
    printf 'cache refreshed (%d pacman %s pending)\n' "$updates" "$noun"
else
    printf 'cache refreshed\n'
fi
exit 0
