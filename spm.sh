#!/bin/bash

#SPM Simple Package Manager
#dependencies: fzf yay

# Check if the script is being sourced
(return 0 2>/dev/null) && sourced=1 || sourced=0

# Define the update cache file path
UPDATE_CACHE_FILE="/var/cache/spm/update-cache.txt"

# Function to clear the screen and display the script name
clear_screen() {
    clear
    local packages=$(pacman -Q | wc -l)
    local updates=$(cat "$UPDATE_CACHE_FILE")
    local pacman_cache=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    local yay_cache=$(du -sh ~/.cache/yay/ 2>/dev/null | cut -f1)
    local bold=$(tput bold)
    local cyan=$(tput setaf 6)
    local reset=$(tput sgr0)

    echo " ___ ___ __  __"
    echo "/ __| _ \\  \\/  | ${bold}${cyan}Simple Package Manager${reset}"
    echo "\\__ \\  _/ |\\/| | ${bold}Pacman${reset}: $pacman_cache  ${bold}Yay${reset}: $yay_cache"
    echo "|___/_| |_|  |_| ${bold}Packages${reset}: $packages  ${bold}Updates${reset}: $updates"
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
    cat "$UPDATE_CACHE_FILE"
}

print_header() {
    local packages=$(pacman -Q | wc -l)
    local updates=$(cat "$UPDATE_CACHE_FILE")
    local pacman_cache=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    local yay_cache=$(du -sh ~/.cache/yay/ 2>/dev/null | cut -f1)
    local bold=$(tput bold)
    local cyan=$(tput setaf 6)
    local reset=$(tput sgr0)

    echo " ___ ___ __  __"
    echo "/ __| _ \\  \\/  | ${bold}${cyan}Simple Package Manager${reset}"
    echo "\\__ \\  _/ |\\/| | ${bold}Pacman${reset}: $pacman_cache  ${bold}Yay${reset}: $yay_cache"
    echo "|___/_| |_|  |_| ${bold}Packages${reset}: $packages  ${bold}Updates${reset}: $updates"
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
    echo "If no option is provided, the interactive menu will be launched."
    echo
    echo
    echo "Enable Optional Shell Sources for standalone arguments:"
    echo
    echo "Note: The following commands can be used as standalone arguments:"
    echo "   install       $ install fzf"
    echo "   remove        $ remove fzf"
    echo "   update        $ update"
    echo "   orphan        $ orphan"
    echo "   downgrade     $ downgrade"
    echo
    echo "1. For Bash users:"
    echo "echo 'source /usr/bin/spm' >> ~/.bashrc"
    echo
    echo "2. For Fish users:"
    echo "echo 'source /usr/share/fish/vendor_functions.d/spm.fish' >> ~/.config/fish/config.fish"
    echo
    echo
    echo "To enable (Required) available update checking:"
    echo "systemctl enable --now spm_updates.timer"
    echo
}

# Function to handle return to Main Menu
handle_return() {
    echo -e "\nPress Ctrl+C to exit or any other key to return to the Main Menu."
    read -n 1 -rs key
    if [[ "$key" == $'\x03' ]]; then
        exit 0
    else
        clear_screen
        manager
    fi
}

# Update Packages
update() {
    clear_screen
    echo "Updating packages..."
    yes | yay
    flatpak update --assumeyes

    # Reset the update cache if no updates are pending
    if [ ! -s "$UPDATE_CACHE_FILE" ]; then
        echo "0" > "$UPDATE_CACHE_FILE"
    fi
    echo "Update complete and cache reset."
    handle_return
}

# Install Packages
install() {
    clear_screen
    echo "Loading packages... This may take a moment."
    local search_query="$1"
    local fzf_cmd="fzf --reverse --multi --preview '
        if pacman -Qi {1} &>/dev/null; then
            echo \"Package Info (installed):\"
            yay -Qi {1}
            echo
            echo \"Installed Files:\"
            pacman -Ql {1} | grep -v \"/$\" | cut -d\" \" -f2-
        else
            echo \"Package Info (not installed):\"
            yay -Si {1}
            echo
            if yay -Si {1} | grep -q \"^Repository *: aur$\"; then
                echo \"PKGBUILD:\"
                echo \"Loading PKGBUILD... Please wait.\"
                yay -G {1} --noconfirm >/dev/null 2>&1
                if [ -f {1}/PKGBUILD ]; then
                    echo -e \"\\n--- PKGBUILD content ---\\n\"
                    cat {1}/PKGBUILD
                else
                    echo \"PKGBUILD not available\"
                fi
                rm -rf {1} 2>/dev/null
            else
                echo \"Files that would be installed:\"
                yay -Fl {1} 2>/dev/null | awk '\''{print $2}'\'' || echo \"File list not available\"
            fi
        fi
    ' --preview-window=right:60%:wrap --header 'Select packages to install
(TAB to select, ENTER to confirm, Ctrl+C to exit)' --bind 'ctrl-c:abort' --tiebreak=index --sort"

    # Get exact repository order from pacman.conf
    local repo_order=$(grep '^\[.*\]' /etc/pacman.conf | grep -v '^\[options\]' | sed 's/[][]//g')

    # Get list of all available packages and installed packages
    local package_list=$(yay -Sl)
    local installed_packages=$(pacman -Qq)

    # Sort package list based on repository order and installation status
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
        repo = $1
        package = $2
        version = $3
        if (version == "" || version == "unknown") {
            version = "(unknown version)"
        }
        priority = (repo in repo_priority) ? repo_priority[repo] : (repo == "aur" ? 998 : 999)
        installed_priority = (package in is_installed) ? 0 : 1
        status = (package in is_installed) ? "[INSTALLED]" : ""
        if (repo == "aur") {
            printf "%01d %03d %-50s %-20s %s\n", installed_priority, priority, package, repo, status
        } else {
            printf "%01d %03d %-50s %-20s %s\n", installed_priority, priority, package " (" version ")", repo, status
        }
    }' | sort -n | cut -d' ' -f3-)

    # Use fzf to select packages, with initial query if provided
    local selected_packages
    if [ -n "$search_query" ]; then
        selected_packages=$(echo "$sorted_package_list" | eval "$fzf_cmd -q \"$search_query\"" | awk '{print $1}')
    else
        selected_packages=$(echo "$sorted_package_list" | eval "$fzf_cmd" | awk '{print $1}')
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
    handle_return
}

# Remove Package
remove() {
    clear_screen
    local search_query="$1"
    local fzf_cmd="fzf --reverse --multi --preview '
        echo \"Package Info:\"
        yay -Qi {1}
        echo
        echo \"Installed Files:\"
        pacman -Ql {1} | grep -v \"/$\" | cut -d\" \" -f2-
    ' --preview-window=right:60%:wrap --header 'Select packages to remove
(TAB to select, ENTER to confirm, Ctrl+C to exit)' --bind 'ctrl-c:abort'"
    
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
    handle_return
}


# Explore Dependencies
explore_dependencies() {
    while true; do
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
        
        if [ -z "$selected_package" ]; then
            return
        fi

        clear_screen
        echo "Package: $selected_package"
        echo "Description: $(pacman -Qi $selected_package | grep "Description" | cut -d":" -f2)"
        echo
        echo "Required By:"
        pacman -Qi $selected_package | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"
        echo
        read -n 1 -s -r -p "Press any key to continue exploring or Ctrl+C to return to the Dependencies Menu"
    done
}

# Sort Packages by Dependencies Count
sort_packages() {
    while true; do
        clear_screen
        local temp_file=$(mktemp)
        echo "Analyzing dependencies... This may take a moment."
        
        # Get all packages and their dependency counts
        pacman -Qq | while read -r pkg; do
            local dep_count=$(pactree -d 1 -u "$pkg" 2>/dev/null | tail -n +2 | wc -l)
            printf "%03d %s\n" "$dep_count" "$pkg"
        done | sort -rn > "$temp_file"
        
        echo # New line after progress dots

        local fzf_cmd="fzf --reverse --preview 'echo \"Package: {2}\"; echo \"Direct Dependencies: {1}\"; echo; echo \"Description: \$(pacman -Qi {2} | grep \"Description\" | cut -d\":\" -f2)\"; echo; echo \"Direct Dependencies:\"; pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed \"s/^/  /\"; echo; echo \"Optional Dependencies:\"; pacman -Qi {2} | grep -A 100 \"Optional Deps\" | sed -n \"/Optional Deps/,/^$/p\" | sed \"1d;$d\" | sed \"s/^/  /\"' --header 'Sorted by number of direct dependencies.
(Ctrl+C to return)' --bind 'ctrl-c:abort'"
        
        local selected_package=$(cat "$temp_file" | eval "$fzf_cmd" | awk '{print $2}')
        
        if [ -z "$selected_package" ]; then
            rm "$temp_file"
            return
        fi

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
        read -n 1 -s -r -p "Press any key to continue sorting or Ctrl+C to return to the Dependencies Menu"
        rm "$temp_file"
    done
}

# Sort Packages by Exclusive Direct Dependencies Count
sort_packages_by_exclusive_deps() {
    while true; do
        clear_screen
        local temp_file=$(mktemp)
        echo "Analyzing exclusive dependencies... This may take a while."
        
        pacman -Qq | while read -r pkg; do
            local exclusive_deps=$(pacman -Rsp "$pkg" 2>/dev/null | grep -v "^$pkg")
            local exclusive_dep_count=$(echo "$exclusive_deps" | wc -l)
            printf "%03d %s\n" "$exclusive_dep_count" "$pkg"
        done | sort -rn > "$temp_file"
        
        echo # New line after progress dots

        local fzf_cmd="fzf --reverse --preview 'echo \"Package: {2}\"; echo \"Exclusive Direct Dependencies: {1}\"; echo; echo \"Description: \$(pacman -Qi {2} | grep \"Description\" | cut -d\":\" -f2)\"; echo; echo \"All Direct Dependencies:\"; pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed \"s/^/  /\"; echo; echo \"Optional Dependencies:\"; pacman -Qi {2} | grep -A 100 \"Optional Deps\" | sed -n \"/Optional Deps/,/^$/p\" | sed \"1d;$d\" | sed \"s/^/  /\"' --header 'Sorted by number of exclusive direct dependencies.
(Ctrl+C to return)' --bind 'ctrl-c:abort'"
        
        local selected_package=$(cat "$temp_file" | eval "$fzf_cmd" | awk '{print $2}')
        
        if [ -z "$selected_package" ]; then
            rm "$temp_file"
            return
        fi

        clear_screen
        echo "Package: $selected_package"
        echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2)"
        echo
        echo "All Direct Dependencies: $(pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | wc -l)"
        echo "All Direct Dependencies:"
        pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | sed "s/^/  /"
        echo
        echo "Exclusive Direct Dependencies: $(pacman -Rsp "$selected_package" 2>/dev/null | grep -v "^$selected_package" | wc -l)"
        echo "Optional Dependencies:"
        pacman -Qi "$selected_package" | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"
        echo
        echo "Required By:"
        pacman -Qi "$selected_package" | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"
        echo
        read -n 1 -s -r -p "Press any key to continue sorting or Ctrl+C to return to the Dependencies Menu"
        rm "$temp_file"
    done
}

# Dependencies Header
print_dependencies_header() {
    local packages=$(pacman -Q | wc -l)
    local updates=$(cat "$UPDATE_CACHE_FILE")
    local pacman_cache=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    local yay_cache=$(du -sh ~/.cache/yay/ 2>/dev/null | cut -f1)
    local bold=$(tput bold)
    local cyan=$(tput setaf 6)
    local reset=$(tput sgr0)

    echo " ___ ___ __  __"
    echo "/ __| _ \\  \\/  | ${bold}${cyan}Simple Package Manager${reset} - Dependencies Sub-Menu"
    echo "\\__ \\  _/ |\\/| | ${bold}Pacman${reset}: $pacman_cache  ${bold}Yay${reset}: $yay_cache"
    echo "|___/_| |_|  |_| ${bold}Packages${reset}: $packages  ${bold}Updates${reset}: $updates"
    echo
}





# Dependencies Menu
dependencies_menu() {
    while true; do
        clear
        print_dependencies_header

        local options=("Explore Dependencies" "Sort by # of Dependencies" "Sort by # of Exclusive Dependencies" "Return to Main Menu")
        local header_height=8  # Adjust this based on the number of lines in your header
        local menu_height=$(($(tput lines) - $header_height - 1))

        local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse --header "Select a function to run (Ctrl+C to Return)" --bind 'ctrl-c:abort' --no-info --height $menu_height --layout=reverse-list)

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
            "Return to Main Menu"|"")
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

        local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse --header "Select a function to run (Ctrl+C to Exit)" --bind 'ctrl-c:abort' --no-info --height $menu_height --layout=reverse-list)

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
            "Exit"|"")
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
                exit 0
                ;;
        esac
    done
}

# Main execution
if [ $sourced -eq 0 ]; then
    # Create or initialize the update cache file if it doesn't exist
    [ ! -f "$UPDATE_CACHE_FILE" ] && echo "0" > "$UPDATE_CACHE_FILE"

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
