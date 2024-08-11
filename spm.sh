#!/bin/bash

#SPM Simple Package Manager
#dependencies: fzf yay

# Check if the script is being sourced
(return 0 2>/dev/null) && sourced=1 || sourced=0

# Function to clear the screen and display the script name
clear_screen() {
    clear
    echo "SPM - Simple Package Manager"
    echo "============================"
    echo
}

# Function to get cache sizes
get_cache_sizes() {
    pacman_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    yay_size=$(du -sh ~/.cache/yay/ 2>/dev/null | cut -f1)
    echo "Pacman cache: ${pacman_size:-0B}, Yay cache: ${yay_size:-0B}"
}

# Function to get available updates
get_available_updates() {
    cat /var/cache/update-cache.txt
}

# Function to print the ASCII art header
print_header() {
    local packages=$(pacman -Q | wc -l)
    local updates=$(cat /var/cache/update-cache.txt)
    local pacman_cache=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    local yay_cache=$(du -sh ~/.cache/yay/ 2>/dev/null | cut -f1)

    echo "   _____  _____  __  __"
    echo "  / ____||  __ \|  \/  |   Simple Package Manager"
    echo " | (___  | |__) | \  / |   ----------------------"
    echo "  \___ \ |  ___/| |\/| |   Pacman: $pacman_cache     Yay: $yay_cache"
    echo "  ____) || |    | |  | |   Packages: $packages  Updates: $updates"
    echo " |_____/ |_|    |_|  |_|"
    echo
}

# Show help menu
show_help() {
    clear_screen
    echo "Usage: spm [options]"
    echo
    echo "Options:"
    echo " -u, update      Update packages"
    echo " -i, install     Install package"
    echo " -r, remove      Remove package"
    echo " -o, orphan      Clean orphaned packages"
    echo " -d, downgrade   Downgrade a package"
    echo " -c, cache       Clear package cache"
    echo " -h, --help      Display this help message"
    echo
    echo "Example:"
    echo " $ spm -i fzf	 # Install packages"
    echo " $ spm -r fzf    # Remove packages"
    echo " $ spm -u        # Update packages (alternative)"
    echo " $ spm -o        # Clean orphaned packages (alternative)"
    echo " $ spm -d        # Downgrade a package"
    echo " $ spm -c        # Clear package cache"
    echo
    echo "Note: The following commands can be used as standalone arguments:"
    echo "  install        $ install fzf"
    echo "  remove         $ remove fzf"
    echo "  update         $ update"
    echo "  orphan         $ orphan"
    echo
}

# Function to handle return to Main Menu
handle_return() {
    echo -e "\nPress Enter to return to the Main Menu or any other key to exit."
    read -n 1 -rs key
    if [[ -z "$key" ]]; then
        clear_screen
        manager
    else
        exit 0
    fi
}

# Update Packages
update() {
    clear_screen
    echo "Updating packages..."
    yes | yay
    flatpak update --assumeyes

    # Reset the update cache if no updates are pending
    if [ ! -s /var/cache/update-cache.txt ]; then
        echo "0" > /var/cache/update-cache.txt
    fi
    echo "Update complete and cache reset."
    handle_return
}

# Install Packages
install() {
    clear_screen
    echo "Loading packages... This may take a moment."
    local search_query="$1"
    local fzf_cmd="fzf --reverse --multi --ansi --preview 'yay -Si {1}' --header 'Select packages to install
(TAB to select, ENTER to confirm, Ctrl+C to return)' --bind 'ctrl-c:abort'"
    
    # Get exact repository order from pacman.conf
    local repo_order=$(grep '^\[.*\]' /etc/pacman.conf | grep -v '^\[options\]' | sed 's/[][]//g')
    
    # Get list of all available packages
    local package_list=$(yay -Sl | awk '{print $2 " " $1}')
    
    # Get list of installed packages
    local installed_packages=$(pacman -Qq)
    
    # Sort package list based on exact repository order and add [INSTALLED] identifier
    local sorted_package_list=$(echo "$package_list" | awk -v repo_order="$repo_order" -v installed="$installed_packages" '
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
        package = $1
        repo = $2
        priority = (repo in repo_priority) ? repo_priority[repo] : 999
        if (package in is_installed) {
            printf "%03d %s %s [INSTALLED]\n", priority, package, repo
        } else {
            printf "%03d %s %s\n", priority, package, repo
        }
    }' | sort -n | cut -d' ' -f2-)
    
    # Use fzf to select packages, with initial query if provided
    local selected_packages
    if [ -n "$search_query" ]; then
        selected_packages=$(echo "$sorted_package_list" | column -t | eval "$fzf_cmd -q \"$search_query\"" | awk '{print $1}')
    else
        selected_packages=$(echo "$sorted_package_list" | column -t | eval "$fzf_cmd" | awk '{print $1}')
    fi
    
    if [ -n "$selected_packages" ]; then
        echo "The following packages will be installed:"
        echo "$selected_packages"
        read -p "Do you want to proceed? [Y/n] " confirm
        case $confirm in
            [Nn]* ) echo "Operation cancelled.";;
            * ) yay -S $selected_packages;;
        esac
    fi
    clear_screen
    manager
}

# Remove Package
remove() {
    clear_screen
    local search_query="$1"
    local fzf_cmd="fzf --reverse --multi --preview 'yay -Qi {1}' --header 'Select packages to remove
(TAB to select, ENTER to confirm, Ctrl+C to return)' --bind 'ctrl-c:abort'"

    # List all installed packages, including dependencies
    local package_list=$(pacman -Qq)

    # Use fzf to select packages, with initial query if provided
    local selected_packages
    if [ -n "$search_query" ]; then
        selected_packages=$(echo "$package_list" | eval "$fzf_cmd -q \"$search_query\"")
    else
        selected_packages=$(echo "$package_list" | eval "$fzf_cmd")
    fi
    
    if [ -n "$selected_packages" ]; then
        echo "The following packages will be removed:"
        echo "$selected_packages"
        read -p "Do you want to proceed? [Y/n] " confirm
        case $confirm in
            [Nn]* ) echo "Operation cancelled.";;
            * ) yay -Rnsc $selected_packages;;
        esac
    fi
    clear_screen
    manager
}

# Explore Dependencies
explore_dependencies() {
    clear_screen
    echo "Explore Dependencies"
    echo "-------------------"
    echo "Use this function to explore package dependencies."
    echo "Press Ctrl+C to return to the Dependencies Menu at any time."
    echo

    local fzf_cmd="fzf --reverse --preview 'echo \"Package: {1}\"; echo \"Description: \$(pacman -Qi {1} | grep \"Description\" | cut -d\":\" -f2)\"; echo; echo \"Required By:\"; pacman -Qi {1} | grep \"Required By\" | cut -d\":\" -f2 | tr \" \" \"\n\" | sed \"s/^/  /\"' --header '(Ctrl+C to return)' --bind 'ctrl-c:abort'"

    # List only dependency packages
    local package_list=$(pacman -Qd | awk '{print $1}')
    local selected_package=$(echo "$package_list" | eval "$fzf_cmd")
    
    if [ -n "$selected_package" ]; then
        clear_screen
        echo "Package: $selected_package"
        echo "Description: $(pacman -Qi $selected_package | grep "Description" | cut -d":" -f2)"
        echo
        echo "Required By:"
        pacman -Qi $selected_package | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"
        echo
        handle_return
    else
        clear_screen
        dependencies_menu
    fi
}

# Sort Packages by Dependencies Count
sort_packages() {
    clear_screen
    local temp_file=$(mktemp)
    echo "Analyzing dependencies... This may take a moment."
    
    # Get all packages and their dependency counts
    pacman -Qq | while read -r pkg; do
        # Count the number of dependencies, subtracting 1 to exclude the package itself from the count
        local dep_count=$(pactree -d 1 -u "$pkg" 2>/dev/null | tail -n +2 | wc -l)
        # Pad the dependency count to ensure proper numerical sorting
        printf "%03d %s\n" "$dep_count" "$pkg"
    done | sort -rn > "$temp_file"
    
    echo # New line after progress dots

    local fzf_cmd="fzf --reverse --preview 'echo \"Package: {2}\"; echo \"Direct Dependencies: {1}\"; echo; echo \"Description: \$(pacman -Qi {2} | grep \"Description\" | cut -d\":\" -f2)\"; echo; echo \"Direct Dependencies:\"; pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed \"s/^/  /\"; echo; echo \"Optional Dependencies:\"; pacman -Qi {2} | grep -A 100 \"Optional Deps\" | sed -n \"/Optional Deps/,/^$/p\" | sed \"1d;$d\" | sed \"s/^/  /\"' --header 'Sorted by number of direct dependencies.
(Ctrl+C to return)' --bind 'ctrl-c:abort'"
    
    local selected_package=$(cat "$temp_file" | eval "$fzf_cmd" | awk '{print $2}')
    if [ -n "$selected_package" ]; then
        clear_screen
        echo "Package: $selected_package"
        echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2)"
        echo
        echo "Direct Dependencies: $(pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | wc -l)"
        echo "Direct Dependencies:"
        pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2
        echo
        echo "Optional Dependencies:"
        pacman -Qi "$selected_package" | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"
        echo
        echo "Required By:"
        pacman -Qi "$selected_package" | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"
        echo
        handle_return
    else
        clear_screen
        dependencies_menu
    fi
    # Clean up
    rm "$temp_file"
}

# Sort Packages by Exclusive Direct Dependencies Count
sort_packages_by_exclusive_deps() {
    clear_screen
    local temp_file=$(mktemp)
    echo "Analyzing exclusive dependencies... This may take a while."
    
    # Get all packages and their exclusive dependency counts
    pacman -Qq | while read -r pkg; do
        # Get all direct dependencies
        local all_deps=$(pactree -d 1 -u "$pkg" 2>/dev/null | tail -n +2)
        # Get dependencies that would be removed with the package (exclusive dependencies)
        local exclusive_deps=$(pacman -Rsp "$pkg" 2>/dev/null | grep -v "^$pkg")
        # Count the number of exclusive dependencies
        local exclusive_dep_count=$(echo "$exclusive_deps" | wc -l)
        # Pad the dependency count to ensure proper numerical sorting
        printf "%03d %s\n" "$exclusive_dep_count" "$pkg"
    done | sort -rn > "$temp_file"
    
    echo # New line after progress dots

    local fzf_cmd="fzf --reverse --preview 'echo \"Package: {2}\"; echo \"Exclusive Direct Dependencies: {1}\"; echo; echo \"Description: \$(pacman -Qi {2} | grep \"Description\" | cut -d\":\" -f2)\"; echo; echo \"All Direct Dependencies:\"; pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed \"s/^/  /\"; echo; echo \"Optional Dependencies:\"; pacman -Qi {2} | grep -A 100 \"Optional Deps\" | sed -n \"/Optional Deps/,/^$/p\" | sed \"1d;$d\" | sed \"s/^/  /\"' --header 'Sorted by number of exclusive direct dependencies.
(Ctrl+C to return)' --bind 'ctrl-c:abort'"

#echo \"Exclusive Direct Dependencies:\"; pacman -Rsp {2} 2>/dev/null | grep -v \"^{2}\" | sed \"s/^/  /\"; echo;
    
    local selected_package=$(cat "$temp_file" | eval "$fzf_cmd" | awk '{print $2}')
    if [ -n "$selected_package" ]; then
        clear_screen
        echo "Package: $selected_package"
        echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2)"
        echo
        echo "All Direct Dependencies: $(pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | wc -l)"
        echo "All Direct Dependencies:"
        pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | sed "s/^/  /"
        echo
        echo "Exclusive Direct Dependencies: $(pacman -Rsp "$selected_package" 2>/dev/null | grep -v "^$selected_package" | wc -l)"
#        echo "Exclusive Direct Dependencies:"
#        pacman -Rsp "$selected_package" 2>/dev/null | grep -v "^$selected_package" | sed "s/^/  /"
#        echo
        echo "Optional Dependencies:"
        pacman -Qi "$selected_package" | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"
        echo
        echo "Required By:"
        pacman -Qi "$selected_package" | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"
        echo
        handle_return
    else
        clear_screen
        dependencies_menu
    fi
    # Clean up
    rm "$temp_file"
}

# Dependencies Menu
dependencies_menu() {
    while true; do
        clear_screen
        local options=("Explore Dependencies" "Sort by # of Dependencies" "Sort by # of Exclusive Dependencies" "Return to Main Menu")
        local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse --header "
	      ================================
              ~ SPM · Simple Package Manager ~
	      ================================
	           ~ Dependencies Menu ~
=========================================================
      Select a function to run (Ctrl+C to Return)
=========================================================

" --bind 'ctrl-c:abort' --no-info)

        case "$selected_option" in
            "Explore Dependencies")
                explore_dependencies
                ;;
            "Sort by # of Dependencies")
                sort_packages
                ;;
            "Sort by # of Exclusive Dependencies")
                sort_packages_by_exclusive_deps
                ;;
            "Return to Main Menu")
                return
                ;;
            *)
                return
                ;;
        esac
    done
}

# Remove orphaned packages
orphan() {
    clear_screen
    echo "Checking for orphaned and unneeded packages..."
    
    orphans=$(pacman -Qdtq)
    unneeded=$(pacman -Qqd | pacman -Rsu --print - 2>&1)

    if [ -z "$orphans" ] && [ "$unneeded" == "there is nothing to do" ]; then
        echo "No orphaned or unneeded packages found."
        handle_return
        return
    fi

    if [ -n "$orphans" ]; then
        echo "The following orphaned packages were found:"
        echo "$orphans"
        echo
        read -p "Do you want to remove these orphaned packages? [Y/n] " confirm
        if [[ ! $confirm =~ ^[Nn](o)?$ ]]; then
            sudo pacman -Rns $orphans
        else
            echo "No orphaned packages were removed."
        fi
    else
        echo "No orphaned packages found."
    fi

    echo
    if [ "$unneeded" != "there is nothing to do" ]; then
        echo "The following additional unneeded packages were found:"
        echo "$unneeded"
        echo
        read -p "Do you want to remove these unneeded packages? [N/y] " confirm
        if [[ $confirm =~ ^[Yy](es)?$ ]]; then
            sudo pacman -Rsu $(pacman -Qqd)
        else
            echo "No unneeded packages were removed."
        fi
    else
        echo "No additional unneeded packages found."
    fi

    handle_return
}

# Downgrade a package
downgrade() {
    clear_screen
    echo "Downgrade Package"
    echo "-----------------"
    echo "Use this function to downgrade a package to a previous version."
    echo "Press Ctrl+C to return to the Main Menu at any time."
    echo

    local package="$1"
    
    if [ -z "$package" ]; then
        echo "Selecting a package to downgrade..."
        package=$(pacman -Qq | fzf --reverse --preview 'pacman -Qi {}' --header 'Select a package to downgrade
(ENTER to confirm, Ctrl+C to return)' --bind 'ctrl-c:abort')
        
        if [ -z "$package" ]; then
            echo "No package selected or operation aborted. Returning to Main Menu."
            clear_screen
            manager
            return
        fi
    fi

    echo "Searching for previous versions of $package..."

    # Check if package is installed
    if ! pacman -Qi "$package" > /dev/null 2>&1; then
        echo "Package $package is not installed."
        handle_return
        return
    fi

    # Get available versions from cache
    versions=$(ls /var/cache/pacman/pkg/${package}-[0-9]*.pkg.tar.* 2> /dev/null | sort -V -r)

    if [ -z "$versions" ]; then
        echo "No cached versions found for $package."
        read -p "Do you want to search the ALA (Arch Linux Archive)? [Y/n] " search_ala
        if [[ ! $search_ala =~ ^[Nn](o)?$ ]]; then
            # Search ALA and present options
            ala_versions=$(curl -s "https://archive.archlinux.org/packages/${package:0:1}/$package/" | grep -o "$package-[0-9].*xz" | sort -V -r)
            if [ -z "$ala_versions" ]; then
                echo "No versions found in ALA for $package."
                handle_return
                return
            fi
            versions=$ala_versions
        else
            clear_screen
            manager
            return
        fi
    fi

    # Present versions to user using fzf
    selected_version=$(echo "$versions" | fzf --reverse --header "Select a version to downgrade $package
(ENTER to confirm, Ctrl+C to return)" --bind 'ctrl-c:abort')

    if [ -n "$selected_version" ]; then
        if [[ $selected_version == http* ]]; then
            # Download from ALA
            wget "https://archive.archlinux.org/packages/${package:0:1}/$package/$selected_version"
            sudo pacman -U "$selected_version"
        else
            # Install from cache
            sudo pacman -U "$selected_version"
        fi
    else
        echo "No version selected or operation aborted. Returning to Main Menu."
    fi
    handle_return
}

# Clear Package Cache
clear_cache() {
    clear_screen
    echo "Clearing Package Cache"
    echo "----------------------"
    echo "This will clear both yay and pacman caches."
    echo

    read -p "Do you want to proceed? [Y/n] " confirm
    case $confirm in
        [Nn]* ) 
            echo "Operation cancelled."
            ;;
        * ) 
            echo "Clearing pacman cache..."
            sudo pacman -Scc --noconfirm
            echo "Clearing yay cache..."
            yay -Scc --noconfirm
            echo "Cache cleared successfully
."
            ;;
    esac

    # Recalculate cache sizes after cleaning
    get_cache_sizes

    handle_return
}

manager() {
    while true; do
        clear
        print_header

        local options=("Install Packages" "Remove Packages" "Update Packages" "Clean Orphans" "Dependencies" "Downgrade Package" "Clear Package Cache" "Exit")
        local header_height=8  # Adjust this based on the number of lines in your header
        local menu_height=$(($(tput lines) - $header_height - 1))

        local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse --header "Select a function to run (Ctrl+C to Return or Exit)" --bind 'ctrl-c:abort' --no-info --height $menu_height --layout=reverse-list)

        case "$selected_option" in
            "Update Packages")
                update
                ;;
            "Install Packages")
                install
                ;;
            "Remove Packages")
                remove
                ;;
            "Dependencies")
                dependencies_menu
                ;;
            "Clean Orphans")
                orphan
                ;;
            "Downgrade Package")
                downgrade
                ;;
            "Clear Package Cache")
                clear_cache
                ;;
            "Exit")
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
                exit 0
                ;;
            *)
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
                exit 0
                ;;
        esac
    done
}

# Main execution
if [ $sourced -eq 0 ]; then
    if [ $# -eq 0 ]; then
        manager
    else
        case "$1" in
            -u|update)
                update
                ;;
            -i|install)
                shift
                install "$*"
                ;;
            -r|remove)
                shift
                remove "$*"
                ;;
            -o|orphan)
                orphan
                ;;
            -d|downgrade)
                downgrade "$2"
                ;;
            -c|cache)
                clear_cache
                ;;
            -h|--help)
                show_help
                ;;
            *)
                echo "Invalid option: $1"
                show_help
                exit 1
                ;;
        esac
    fi
fi