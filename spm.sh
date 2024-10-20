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
    print_header
}

# Function to initialize or read the preview width
get_preview_width() {
    local preview_file="/tmp/spm_preview_width"
    if [[ ! -f "$preview_file" ]]; then
        echo "60" > "$preview_file"
    fi
    cat "$preview_file"
}

# Pacman Cache
get_pacman_cache_size() {
    local cache_dir="/var/cache/pacman/pkg"
    local size=$(find "$cache_dir" -type f -name "*.pkg.tar*" -print0 | du -ch --files0-from=- 2>/dev/null | tail -n 1 | cut -f1)
    if [[ -z "$size" || "$size" == "0" || "$size" == "0B" ]]; then
        echo "0"
    else
        echo "$size"
    fi
}

# Yay Cache
get_yay_cache_size() {
    local cache_dir="$HOME/.cache/yay"
    local size=$(find "$cache_dir" -type f \( -name "*.pkg.tar*" -o -name "*.src.tar.gz" \) -print0 | du -ch --files0-from=- 2>/dev/null | tail -n 1 | cut -f1)
    if [[ -z "$size" || "$size" == "0" || "$size" == "0B" ]]; then
        echo "0"
    else
        echo "$size"
    fi
}

# Function to print the header
print_header() {
    local packages=$(pacman -Q | wc -l)
    local updates=$(cat "$UPDATE_CACHE_FILE")
    local pacman_cache=$(get_pacman_cache_size)
    local yay_cache=$(get_yay_cache_size)
    local bold=$(tput bold)
    local cyan=$(tput setaf 6)
    local reset=$(tput sgr0)

    printf " ___ ___ __  __\n"
    printf "/ __| _ \\  \\/  | ${bold}${cyan}Simple Package Manager${reset}\n"
    printf "\\__ \\  _/ |\\/| | ${bold}Pacman${reset} %-9s ${bold}Yay${reset} %-9s\n" "$pacman_cache" "$yay_cache"
    printf "|___/_| |_|  |_| ${bold}Packages${reset} %-7d ${bold}Updates${reset} %-7d\n" "$packages" "$updates"
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
    echo "Update Packages"
    echo "---------------"
    
    # Check if we're running in a terminal
    if [ -t 0 ]; then
        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"
        local detailed_cache_file="/var/cache/spm/detailed-update-cache.txt"
        local menu_height

        # Initialize resize flag
        echo 0 > "$resize_flag"

        # Set menu height based on terminal size
        if [ -n "$LINES" ]; then
            menu_height=$((LINES - 10))
        else
            menu_height=15  # Default value if LINES is not set
        fi
    else
        # Set default values when not in a terminal
        local preview_width=50
        local menu_height=15
    fi

    local options=(
        "Quick Full Update (Auto-yes for yay and Flatpak)"
        "Full Update (Review changes for yay and Flatpak)"
        "yay Update (Review changes)"
        "Flatpak Update (Review changes)"
        "Return to Main Menu"
    )

    while true; do
        if [ -t 0 ]; then
            preview_width=$(cat "$preview_file")
            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    echo "${bold}Upgradable Packages:${normal}"
                    echo
                    cat "'$detailed_cache_file'" 2>/dev/null || echo "No update information available."
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label='Available Updates' \
                --no-info \
                --height $menu_height \
                --layout=reverse-list \
                --header "Select an update option. Alt-[ move preview left, Alt-] move preview right.
(ENTER to confirm, Ctrl+C to return to main menu)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --ansi)
        else
            # When not in a terminal, default to Quick Full Update
            local selected_option="Quick Full Update (Auto-yes for yay and Flatpak)"
        fi

        if [[ -z "$selected_option" ]]; then
            if [ -t 0 ] && [[ $(cat "$resize_flag") -eq 1 ]]; then
                echo 0 > "$resize_flag"
                continue
            else
                return
            fi
        fi

        case "$selected_option" in
            "Quick Full Update"*)
                echo "Performing quick update..."
                yes | yay
                flatpak update --assumeyes
                break
                ;;
            "Full Update"*)
                echo "Performing full update..."
                yay
                flatpak update
                break
                ;;
            "yay Update"*)
                echo "Updating yay packages..."
                yay
                break
                ;;
            "Flatpak Update"*)
                echo "Updating Flatpak apps..."
                flatpak update
                break
                ;;
            "Return to Main Menu")
                return
                ;;
        esac
    done

    # Call spm_updates to update cache in main menu
    if [ "$(id -u)" -eq 0 ]; then
        # If running as root, directly call spm_updates
        /usr/bin/spm_updates
    else
        # If not root, start the user timer
        systemctl start --user spm_updates.timer
        echo "Update check scheduled. Cache will be updated shortly."
    fi
}

# Install Packages
install() {
    local exit_function=false
    while ! $exit_function; do
        clear_screen
        echo "Install Packages"
        echo "----------------"
        echo "Loading packages... This may take a moment."
        local search_query="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

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

        while true; do
            preview_width=$(cat "$preview_file")
            local fzf_options=(
                -m --reverse
                --preview '
                    if pacman -Qi {1} &>/dev/null; then
                        echo "Package Info (installed):"
                        yay -Qi {1}
                        echo
                        echo "Installed Files:"
                        pacman -Ql {1} | grep -v "/$" | cut -d" " -f2-
                    else
                        echo "Package Info (not installed):"
                        yay -Si {1}
                        echo
                        if yay -Si {1} | grep -q "^Repository *: aur$"; then
                            echo "PKGBUILD:"
                            echo "Loading PKGBUILD... Please wait."
                            yay -G {1} --noconfirm >/dev/null 2>&1
                            if [ -f {1}/PKGBUILD ]; then
                                echo -e "\n--- PKGBUILD content ---\n"
                                cat {1}/PKGBUILD
                            else
                                echo "PKGBUILD not available"
                            fi
                            rm -rf {1} 2>/dev/null
                        else
                            echo "Files that would be installed:"
                            yay -Fl {1} 2>/dev/null | awk '\''{print $2}'\'' || echo "File list not available"
                        fi
                    fi
                '
                --preview-window="right:$preview_width%:wrap"
                --header "Select package(s) to install. Alt-[ move preview left, Alt-] move preview right.
(TAB to select, ENTER to confirm, Ctrl+C to return)"
                --bind 'ctrl-c:abort'
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort"
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort"
                --tiebreak=index
            )

            # Add search query option if provided
            [[ -n "$search_query" ]] && fzf_options+=(-q "$search_query")

            local selected_packages=$(echo "$sorted_package_list" | fzf "${fzf_options[@]}" | awk '{print $1}')

            # Check if we need to exit or if it was just a resize operation
            if [[ -z "$selected_packages" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    exit_function=true
                    break
                fi
            fi

            if [ -n "$selected_packages" ]; then
                echo "The following packages will be installed:"
                echo -e "$(echo "$selected_packages" | sed 's/^/\\033[1m/' | sed 's/$/\\033[0m/')"
                read -p "Do you want to proceed? [Y/n] " confirm
                case $confirm in
                    [Nn]* ) echo "Operation cancelled.";;
                    * ) yay -S $selected_packages;;
                esac
            fi

            echo -e "\nPress Ctrl+C to exit or any other key to return to the package selection."
            read -n 1 -s -r key
            if [[ "$key" == $'\x03' ]]; then
                exit_function=true
            fi
            break
        done
    done

    if [ $sourced -eq 0 ]; then
        # If not sourced, return to the main menu
        handle_return
    fi
}

remove() {
    local exit_function=false
    while ! $exit_function; do
        clear_screen
        local search_query="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            local fzf_options=(
                -m --reverse
                --preview '
                    yay -Qi {1}
                    echo
                    echo "Installed Files:"
                    pacman -Ql {1} | grep -v "/$" | cut -d" " -f2-
                '
                --preview-window="right:$preview_width%:wrap"
                --preview-label='Package Info (to Remove)'
                --header "Select package(s) to remove. Alt-[ move preview left, Alt-] move preview right.
(TAB to select, ENTER to confirm, Ctrl+C to exit)"
                --bind 'ctrl-c:abort'
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort"
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort"
            )

            # Add search query option if provided
            [[ -n "$search_query" ]] && fzf_options+=(-q "$search_query")

            local selected_packages=$(pacman -Qq | fzf "${fzf_options[@]}")

            # Check if we need to exit or if it was just a resize operation
            if [[ -z "$selected_packages" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    exit_function=true
                    break
                fi
            fi

            if [ -n "$selected_packages" ]; then
                echo "The following packages will be removed:"
                echo -e "$(echo "$selected_packages" | sed 's/^/\\033[1m/' | sed 's/$/\\033[0m/')"
                echo
                
                echo "Package Removal Options"
                echo "------------------------"
                
                local pacman_args
                while true; do
                    echo "1) Remove package, dependencies, config files, and dependencies of other packages (-Rnsc) [Default]"
                    echo "2) Remove package, dependencies, and configuration files (-Rns)"
                    echo "3) Remove package and configuration files (-Rn)"
                    echo "4) Remove package and its dependencies (-Rs)"
                    echo "5) Remove package only (-R)"
                    echo "6) Remove package and ignore dependencies (-Rdd)"
                    echo "7) Remove package and ignore dependencies and configuration files (-Rddn)"
                    echo "8) Cancel removal"
                    echo
                    read -p "Enter option (1-8) [1]: " remove_option

                    case $remove_option in
                        1|"") pacman_args="-Rnsc"; break;;
                        2) pacman_args="-Rns"; break;;
                        3) pacman_args="-Rn"; break;;
                        4) pacman_args="-Rs"; break;;
                        5) pacman_args="-R"; break;;
                        6) pacman_args="-Rdd"; break;;
                        7) pacman_args="-Rddn"; break;;
                        8) 
                            echo "Operation cancelled."
                            exit_function=true
                            break 2
                            ;;
                        *) echo "Invalid option. Please try again.";;
                    esac
                done

                read -p "Proceed with removal using $pacman_args? [Y/n] " confirm
                case $confirm in
                    [Nn]* ) echo "Operation cancelled.";;
                    * ) yay $pacman_args $selected_packages;;
                esac
                break
            fi
        done

        if ! $exit_function; then
            echo -e "\nPress Ctrl+C to exit or any other key to return to the Main Menu."
            read -n 1 -s -r key
            if [[ "$key" == $'\x03' ]]; then
                exit_function=true
            fi
        fi
    done

    if [ $sourced -eq 0 ]; then
        # If not sourced, return to the main menu
        handle_return
    fi
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

        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            
            # List only dependency packages
            local package_list=$(pacman -Qd | awk '{print $1}')
            local selected_package=$(echo "$package_list" | fzf --reverse \
                --preview 'echo "Package: {1}"; echo "Description: $(pacman -Qi {1} | grep "Description" | cut -d":" -f2)"; echo; echo "Required By:"; pacman -Qi {1} | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label='Dependency Info' \
                --header "Select a package to explore. Alt-[ move preview left, Alt-] move preview right.
(ENTER to confirm, Ctrl+C to return)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort")
            
            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    return
                fi
            fi

            clear_screen
            echo "Package: $selected_package"
            echo "Description: $(pacman -Qi $selected_package | grep "Description" | cut -d":" -f2)"
            echo
            echo "Required By:"
            pacman -Qi $selected_package | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "s/^/  /"
            echo
            read -n 1 -s -r -p "Press any key to continue exploring or Ctrl+C to return to the Dependencies Menu"
            break
        done
    done
}

# Sort Packages by # of Dependencies
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

        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            local selected_package=$(cat "$temp_file" | fzf --reverse \
                --preview 'echo "Package: {2}"; echo "Direct Dependencies: {1}"; echo; echo "Description: $(pacman -Qi {2} | grep "Description" | cut -d":" -f2)"; echo; echo "Direct Dependencies:"; pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed "s/^/  /"; echo; echo "Optional Dependencies:"; pacman -Qi {2} | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label='Package Dependencies' \
                --header "Sorted by number of direct dependencies. Alt-[ move preview left, Alt-] move preview right.
(ENTER to select, Ctrl+C to return)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                | awk '{print $2}')
            
            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    rm "$temp_file"
                    return
                fi
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
            break
        done
        rm "$temp_file"
    done
}

# Sort Packages by Exclusive Direct Dependencies
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
        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            local selected_package=$(cat "$temp_file" | fzf --reverse \
                --preview "echo \"Package: {2}\"; echo \"Exclusive Direct Dependencies: {1}\"; echo; echo \"Description: \$(pacman -Qi {2} | grep \"Description\" | cut -d\":\" -f2)\"; echo; echo \"All Direct Dependencies:\"; pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed \"s/^/  /\" | sed 's/.\{120\}/&\n/g'; echo; echo \"Optional Dependencies:\"; pacman -Qi {2} | grep -A 100 \"Optional Deps\" | sed -n \"/Optional Deps/,/^$/p\" | sed \"1d;$d\" | sed \"s/^/  /\"; echo; echo \"Required By:\"; pacman -Qi {2} | grep \"Required By\" | cut -d\":\" -f2 | tr \" \" \"\n\" | sed \"/^$/d\" | sed \"s/^/  /\"; echo; pacman -Qi {2} | grep -E \"Build Date|Install Date|Install Reason|Install Script\"" \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label='Exclusive Direct Dependencies' \
                --header "Sorted by number of exclusive direct dependencies. Alt-[ decrease preview size, Alt-] increase.
(Ctrl+C to return)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                | awk '{print $2}')
            
            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    rm "$temp_file"
                    return
                fi
            fi

            clear_screen
            echo "Package: $selected_package"
            echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2)"
            echo
            echo "All Direct Dependencies: $(pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | wc -l)"
            echo "All Direct Dependencies:"
            pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | sed "s/^/  /" | sed 's/.\{120\}/&\n/g'
            echo
            echo "Exclusive Direct Dependencies: $(pacman -Rsp "$selected_package" 2>/dev/null | grep -v "^$selected_package" | wc -l)"
            echo "Optional Dependencies:"
            pacman -Qi "$selected_package" | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"
            echo
            echo "Required By:"
            pacman -Qi "$selected_package" | grep "Required By" | cut -d":" -f2 | tr " " "\n" | sed "/^$/d" | sed "s/^/  /"
            echo
            pacman -Qi "$selected_package" | grep -E "Build Date|Install Date|Install Reason|Install Script"
            echo
            read -n 1 -s -r -p "Press any key to continue sorting or Ctrl+C to return to the Dependencies Menu"
            break
        done
        rm "$temp_file"
    done
}
# Dependencies Menu
dependencies_menu() {
    while true; do
        clear
        print_header

        local options=("Explore Dependencies" "Sort by # of Dependencies" "Sort by # of Exclusive Dependencies" "Return to Main Menu")
        local header_height=8
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
    while true; do
        clear_screen
        echo "Clean Orphans"
        echo "-------------"
        
        # Check if we're running in a terminal
        if [ -t 0 ]; then
            local preview_width=$(get_preview_width)
            local preview_file="/tmp/spm_preview_width"
            local resize_flag="/tmp/spm_resize_flag"

            # Initialize resize flag
            echo 0 > "$resize_flag"

            local options=(
                "Quick remove all orphaned and unneeded packages (auto-yes)"
                "Remove orphaned packages"
                "Remove unneeded packages"
                "Review and remove both orphaned and unneeded packages"
                "Return to Main Menu"
            )

            # Generate preview content
            local preview_content=$(
                bold=$(tput bold)
                normal=$(tput sgr0)
                echo "${bold}Orphaned Packages:${normal}"
                pacman -Qdtq
                echo
                echo "${bold}Unneeded packages:${normal}"
                pacman -Qqd | pacman -Rsu --print - 2>/dev/null
            )

            preview_width=$(cat "$preview_file")
            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --preview "echo \"$preview_content\"" \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label='Orphaned and Unneeded Packages' \
                --no-info \
                --height 80% \
                --layout=reverse-list \
                --header "Select an option to clean orphans. Alt-[ move preview left, Alt-] move preview right.
(ENTER to confirm, Ctrl+C to return to main menu)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    return
                fi
            fi

            if [ "$selected_option" = "Return to Main Menu" ]; then
                return
            fi

            process_orphan_option "$selected_option"
            
            echo
            read -n 1 -s -r -p "Press any key to continue..."
        else
            # Non-interactive mode: perform quick remove
            echo "Performing quick remove of orphaned and unneeded packages..."
            sudo pacman -Rns $(pacman -Qdtq) --noconfirm
            sudo pacman -Rsu $(pacman -Qqd) --noconfirm
            echo "Removal complete."
            return
        fi
    done
}

# Helper function to process orphan removal options
process_orphan_option() {
    local option="$1"
    case "$option" in
        "Quick remove all orphaned and unneeded packages (auto-yes)")
            sudo pacman -Rns $(pacman -Qdtq) --noconfirm
            sudo pacman -Rsu $(pacman -Qqd) --noconfirm
            echo "Removal complete."
            ;;
        "Remove orphaned packages")
            local orphans=$(pacman -Qdtq)
            if [ -n "$orphans" ]; then
                echo "The following orphaned packages will be removed:"
                echo "$orphans"
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                if [[ ! $confirm =~ ^[Nn](o)?$ ]]; then
                    sudo pacman -Rns $orphans
                else
                    echo "No orphaned packages were removed."
                fi
            else
                echo "No orphaned packages found."
            fi
            ;;
        "Remove unneeded packages")
            local unneeded=$(pacman -Qqd | pacman -Rsu --print - 2>/dev/null)
            if [ -n "$unneeded" ]; then
                echo "The following unneeded packages will be removed:"
                echo "$unneeded"
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                if [[ ! $confirm =~ ^[Nn](o)?$ ]]; then
                    sudo pacman -Rsu $unneeded
                else
                    echo "No unneeded packages were removed."
                fi
            else
                echo "No unneeded packages found."
            fi
            ;;
        "Review and remove both orphaned and unneeded packages")
            local orphans=$(pacman -Qdtq)
            local unneeded=$(pacman -Qqd | pacman -Rsu --print - 2>/dev/null)
            if [ -n "$orphans" ] || [ -n "$unneeded" ]; then
                echo "The following packages will be removed:"
                [ -n "$orphans" ] && echo "Orphaned packages:
$orphans"
                [ -n "$unneeded" ] && echo "Unneeded packages:
$unneeded"
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                if [[ ! $confirm =~ ^[Nn](o)?$ ]]; then
                    [ -n "$orphans" ] && sudo pacman -Rns $orphans
                    [ -n "$unneeded" ] && sudo pacman -Rsu $unneeded
                else
                    echo "No packages were removed."
                fi
            else
                echo "No orphaned or unneeded packages found."
            fi
            ;;
        "Return to Main Menu")
            return
            ;;
    esac
}

downgrade() {
    clear_screen
    echo "Downgrade Package(s)"
    echo "--------------------"
    
    local packages="$1"
    local preview_width=$(get_preview_width)
    local preview_file="/tmp/spm_preview_width"
    local resize_flag="/tmp/spm_resize_flag"

    echo 0 > "$resize_flag"
    
    if [ -z "$packages" ]; then
        local fzf_options=(
            --reverse -m
            --preview 'pacman -Qi {}'
            --preview-window="right:$preview_width%:wrap"
            --preview-label='Current Package Version'
            --header "Select package(s) to downgrade. Alt-[ move preview left, Alt-] move preview right.
(TAB to select, ENTER to confirm, Ctrl+C to return)"
            --bind 'ctrl-c:abort'
            --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort"
            --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort"
        )

        while true; do
            preview_width=$(cat "$preview_file")
            packages=$(pacman -Qq | fzf "${fzf_options[@]}")
            
            if [[ -z "$packages" ]]; then
                [[ $(cat "$resize_flag") -eq 1 ]] && { echo 0 > "$resize_flag"; continue; }
                return
            else
                break
            fi
        done
    fi

    for package in $packages; do
        echo "Searching for previous versions of $package..."

        # Check if package is installed
        if ! pacman -Qi "$package" > /dev/null 2>&1; then
            echo "Package $package is not installed. Skipping..."
            continue
        fi

        # Get available versions from cache
        versions=$(ls /var/cache/pacman/pkg/${package}-[0-9]*.pkg.tar.* 2> /dev/null | sort -V -r)

        if [ -z "$versions" ]; then
            echo "No cached versions found for $package."
            read -p "Do you want to search the ALA (Arch Linux Archive) for $package? [Y/n] " search_ala
            if [[ ! $search_ala =~ ^[Nn](o)?$ ]]; then
                # Search ALA and present options
                ala_versions=$(curl -s "https://archive.archlinux.org/packages/${package:0:1}/$package/" | grep -o "$package-[0-9].*xz" | sort -V -r)
                if [ -z "$ala_versions" ]; then
                    echo "No versions found in ALA for $package. Skipping..."
                    continue
                fi
                versions=$ala_versions
            else
                echo "Skipping $package..."
                continue
            fi
        fi

        # Present versions to user using fzf
        while true; do
            preview_width=$(cat "$preview_file")
            selected_version=$(echo "$versions" | fzf --reverse \
                --preview "echo 'Version: {}'
echo
echo 'Package details:'
if [[ {} == http* ]]; then
    curl -s 'https://archive.archlinux.org/packages/${package:0:1}/$package/{}' | grep -E 'href=\".*\"|>.*B</a>'
else
    pacman -Qip {}
fi" \
                --preview-window="right:$preview_width%:wrap" \
                --header "Select a version to downgrade $package. Alt-[ move preview left, Alt-] move preview right.
(ENTER to confirm, Ctrl+C to skip)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort")

            if [[ -z "$selected_version" ]]; then
                if [[ $(cat "$resize_flag") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    echo "No version selected or operation aborted for $package. Skipping..."
                    break
                fi
            else
                break
            fi
        done

        if [ -n "$selected_version" ]; then
            if [[ $selected_version == http* ]]; then
                # Download from ALA
                wget "https://archive.archlinux.org/packages/${package:0:1}/$package/$selected_version"
                sudo pacman -U "$selected_version"
                rm "$selected_version"  # Clean up the downloaded file
            else
                # Install from cache
                sudo pacman -U "$selected_version"
            fi
            echo "Downgrade completed for $package."
        fi
    done
    
    echo "All selected packages have been processed."
    handle_return
}

# Clear Package Cache
clear_cache() {
    while true; do
        clear_screen
        echo "Clear Package Cache"
        echo "-------------------"
        
        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

        local options=(
            "Quick Clear (Auto-yes for all prompts)"
            "Clear Pacman Cache"
            "Clear Yay Cache"
            "Clear Both Caches"
            "Return to Main Menu"
        )

        # Calculate menu height
        local header_height=7  # Adjust this based on the number of lines in your header
        local menu_height=$(($(tput lines) - $header_height - 1))

        preview_width=$(cat "$preview_file")
        local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
            --preview '
                bold=$(tput bold)
                normal=$(tput sgr0)
                echo "${bold}Current Cache Sizes:${normal}"
                echo "Pacman cache: $(du -sh /var/cache/pacman/pkg | cut -f1)"
                echo "Yay cache: $(du -sh ~/.cache/yay 2>/dev/null | cut -f1)"
                echo
                echo "${bold}Total Disk Usage:${normal}"
                df -h / | awk "NR==2 {print \$3 \" used out of \" \$2 \" (\" \$5 \" used)\"}"
                echo
                echo "${bold}Available Space:${normal}"
                df -h / | awk "NR==2 {print \$4}"
            ' \
            --preview-window="right:${preview_width}%:wrap" \
            --preview-label='Cache Information' \
            --no-info \
            --height "$menu_height" \
            --layout=reverse-list \
            --header "Select an option to clear cache. Alt-[ move preview left, Alt-] move preview right.
(ENTER to confirm, Ctrl+C to return to main menu)" \
            --bind 'ctrl-c:abort' \
            --bind "alt-[:execute-silent(echo \$((preview_width + 10 > 90 ? 90 : preview_width + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
            --bind "alt-]:execute-silent(echo \$((preview_width - 10 < 10 ? 10 : preview_width - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
            --ansi)

        if [[ -z "$selected_option" ]]; then
            if [[ $(cat "$resize_flag") -eq 1 ]]; then
                echo 0 > "$resize_flag"
                continue
            else
                return
            fi
        fi

        case "$selected_option" in
            "Quick Clear (Auto-yes for all prompts)")
                echo "Performing quick cache clear..."
                echo "Clearing Pacman cache..."
                sudo pacman -Scc --noconfirm
                echo "Clearing Yay cache..."
                yay -Scc --noconfirm
                ;;
            "Clear Pacman Cache")
                echo "Clearing Pacman cache..."
                sudo pacman -Scc
                ;;
            "Clear Yay Cache")
                echo "Clearing Yay cache..."
                yay -Scc
                ;;
            "Clear Both Caches")
                echo "Clearing Pacman cache..."
                sudo pacman -Scc
                echo "Clearing Yay cache..."
                yay -Scc
                ;;
            "Return to Main Menu")
                return
                ;;
        esac

        echo "Cache clearing operation completed."
        read -n 1 -s -r -p "Press any key to continue..."
    done
}

# Function to display a condensed version of pacman.conf
display_pacman_conf() {
    echo "Pacman Configuration Summary:"
    echo "-----------------------------"
    awk '
    /^\[.*\]/ { 
        print "\n" $0 ":";
        next 
    }
    /^#/ { next }
    /^$/ { next }
    { gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") print "  " $0 }
    ' /etc/pacman.conf
}

# Function to get a description for each option
get_option_description() {
    case "$1" in
        "RootDir") echo "Set the default root directory for pacman to install to.";;
        "DBPath") echo "Overrides the default location of the toplevel database directory.";;
        "CacheDir") echo "Overrides the default location of the package cache directory.";;
        "LogFile") echo "Overrides the default location of the pacman log file.";;
        "GPGDir") echo "Overrides the default location of the directory containing GnuPG configuration files.";;
        "HookDir") echo "Add directories to search for alpm hooks.";;
        "HoldPkg") echo "Packages that should not be removed unless explicitly requested.";;
        "IgnorePkg") echo "Packages that should be ignored during upgrades.";;
        "IgnoreGroup") echo "Groups of packages to ignore during upgrades.";;
        "Architecture") echo "Defines the system architectures pacman will use for package downloads.";;
        "XferCommand") echo "Specifies an external program to handle file downloads.";;
        "NoUpgrade") echo "Files that should never be overwritten during package installation/upgrades.";;
        "NoExtract") echo "Files that should never be extracted from packages.";;
        "CleanMethod") echo "Specifies how pacman cleans up old packages.";;
        "SigLevel") echo "Sets the default signature verification level.";;
        "LocalFileSigLevel") echo "Sets the signature verification level for installing local packages.";;
        "RemoteFileSigLevel") echo "Sets the signature verification level for installing remote packages.";;
        "ParallelDownloads") echo "Specifies the number of concurrent download streams.";;
        "UseSyslog") echo "Log action messages through syslog.";;
        "Color") echo "Automatically enable colors for terminal output.";;
        "NoProgressBar") echo "Disables progress bars.";;
        "CheckSpace") echo "Performs a check for adequate available disk space before installing packages.";;
        "VerbosePkgLists") echo "Displays more detailed package information.";;
        "DisableDownloadTimeout") echo "Disable defaults for low speed limit and timeout on downloads.";;
        "ILoveCandy") echo "Enables a playful pacman-style progress bar.";;
        "Add New Repository") echo "Add a repository with multiple entry prompts.";;
        "Manage Repositories") echo "Comment and uncomment multiple repositories at once.";;
        "Edit pacman.conf directly") echo "Call default text editor to edit pacman.conf.";;
        "Return to Main Menu") echo "..";;
        *) echo "No description available.";;
    esac
}

# Function to display preview content
display_preview() {
    local option="$1"
    local description=$(get_option_description "$option")
    if [ -n "$description" ]; then
        echo -e "\033[1mDescription: $description\033[0m"
        echo
    fi
    display_pacman_conf
}

# Update the edit_pacman_option function
edit_pacman_option() {
    local option="$1"
    local current_value=$(grep "^#*$option" /etc/pacman.conf | sed 's/^#*//; s/.*=//; s/^[[:space:]]*//' | tail -n 1)
    local new_value

    echo "Current value for $option: $current_value"
    echo "Description: $(get_option_description "$option")"
    echo "For multiple values, separate them with spaces."
    read -e -i "$current_value" -p "Enter new value (or press Enter to keep current): " new_value

    if [ -n "$new_value" ] && [ "$new_value" != "$current_value" ]; then
        sudo sed -i "s|^#*$option.*|$option = $new_value|" /etc/pacman.conf
        echo "$option updated to $new_value"
    else
        echo "No changes made to $option"
    fi
}

# Function to toggle boolean options with confirmation
toggle_pacman_option_with_confirmation() {
    local option="$1"
    local current_status
    local new_status

    if grep -q "^$option" /etc/pacman.conf; then
        current_status="enabled"
        new_status="disable"
    elif grep -q "^#$option" /etc/pacman.conf; then
        current_status="disabled"
        new_status="enable"
    else
        current_status="not set"
        new_status="enable"
    fi

    echo "Current status of $option: $current_status"
    echo "Description: $(get_option_description "$option")"
    read -p "Do you want to $new_status $option? [y/N] " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        if [ "$new_status" = "enable" ]; then
            sudo sed -i "s/^#$option/$option/" /etc/pacman.conf
            echo "$option has been enabled."
        else
            sudo sed -i "s/^$option/#$option/" /etc/pacman.conf
            echo "$option has been disabled."
        fi
    else
        echo "No changes made to $option"
    fi
}

# Function to toggle repositories
toggle_repository() {
    local repo="$1"
    if grep -q "^\[$repo\]" /etc/pacman.conf; then
        # Disable the repository
        echo "Disabling repository $repo..."
        sudo sed -i "/^\[$repo\]/,/^$/s/^\([^#]\)/#\1/g" /etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo "$repo repository disabled successfully."
        else
            echo "Failed to disable $repo repository. Make sure you have sudo privileges."
        fi
    elif grep -q "^#\[$repo\]" /etc/pacman.conf; then
        # Enable the repository
        echo "Enabling repository $repo..."
        sudo sed -i "/^#\[$repo\]/,/^$/s/^#//g" /etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo "$repo repository enabled successfully."
        else
            echo "Failed to enable $repo repository. Make sure you have sudo privileges."
        fi
    else
        echo "Repository $repo not found in pacman.conf"
    fi
}

# Function to list and select repositories
manage_repositories() {
    local options=""
    
    # Read through pacman.conf and process lines
    while IFS= read -r line; do
        # Detect commented or uncommented repository headers, exclude [options]
        if [[ $line =~ ^#?\[(.*)\]$ ]]; then
            repo=$(echo "$line" | sed 's/^[[:space:]]*#*\[\(.*\)\][[:space:]]*$/\1/')
            
            # Skip the [options] section
            if [[ "$repo" == "options" ]]; then
                continue
            fi

            # Identify enabled and disabled repositories
            if [[ $line =~ ^# ]]; then
                options+="[DISABLED] $repo"$'\n'
            else
                options+="[ENABLED]  $repo"$'\n'
            fi
        fi
    done < /etc/pacman.conf

    # Remove the trailing newline from options
    options=${options%$'\n'}

    # Check if any repositories were found
    if [ -z "$options" ]; then
        echo "No repositories found in pacman.conf"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    # Display repositories and allow selection
    local selected_repos=$(echo -e "$options" | fzf --reverse --multi --header "Select repositories to toggle (TAB to select multiple, ENTER to confirm, Ctrl+C to Return)" | sed 's/^\[.*\] *//')

    if [ -n "$selected_repos" ]; then
        echo "$selected_repos" | while read -r repo; do
            toggle_repository "$repo"
        done
        echo "Press any key to continue..."
        read -n 1 -s
        display_pacman_conf
    fi
}

# Pacman.conf Fzf Preview
display_preview() {
    local option="$1"
    local description=$(get_option_description "$option")
    local current_value=$(grep "^#*$option" /etc/pacman.conf | sed 's/^#*//; s/.*=//; s/^[[:space:]]*//' | tail -n 1)

    echo -e "\033[1mOption: $option\033[0m"
    echo -e "\033[1mDescription:\033[0m $description"
    echo -e "\033[1mCurrent Value:\033[0m $current_value"
    echo
    echo "Pacman Configuration Summary:"
    echo "-----------------------------"
    awk '
    /^\[.*\]/ { print "\n" $0 ":"; next }
    /^#/ { next }
    /^$/ { next }
    { gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") print "  " $0 }
    ' /etc/pacman.conf
}

# Function to add a new repository
add_repository() {
    local repo_name
    local server_url

    read -p "Enter the name of the new repository: " repo_name
    read -p "Enter the server URL for the repository: " server_url

    echo -e "\n[$repo_name]\nServer = $server_url" | sudo tee -a /etc/pacman.conf > /dev/null
    echo "Repository $repo_name added to pacman.conf"
}

# Pacman Config fzf Menu
pacman_config_menu() {
    while true; do
        clear
        print_header

        local options=(
            "[EDIT] RootDir"
            "[EDIT] DBPath"
            "[EDIT] CacheDir"
            "[EDIT] LogFile"
            "[EDIT] GPGDir"
            "[EDIT] HookDir"
            "[EDIT] Architecture"
            "[EDIT] XferCommand"
            "[EDIT] CleanMethod"
            "[EDIT] HoldPkg"
            "[EDIT] IgnoreGroup"
            "[EDIT] IgnorePkg"
            "[EDIT] NoExtract"
            "[EDIT] NoUpgrade"
            "[EDIT] ParallelDownloads"
            "[EDIT] SigLevel"
            "[EDIT] LocalFileSigLevel"
            "[EDIT] RemoteFileSigLevel"
            "[TOGGLE] CheckSpace"
            "[TOGGLE] Color"
            "[TOGGLE] DisableDownloadTimeout"
            "[TOGGLE] ILoveCandy"
            "[TOGGLE] NoProgressBar"
            "[TOGGLE] UseSyslog"
            "[TOGGLE] VerbosePkgLists"
            "[ACTION] Add New Repository"
            "[ACTION] Manage Repositories"
            "[ACTION] Edit pacman.conf directly"
            "Return to Main Menu"
        )

        local header_height=8
        local menu_height=$(($(tput lines) - $header_height - 1))
        local preview_width=$(get_preview_width)
        local preview_file="/tmp/spm_preview_width"
        local resize_flag="/tmp/spm_resize_flag"

        # Initialize resize flag
        echo 0 > "$resize_flag"

        preview_width=$(cat "$preview_file")
        local selected_option=$(printf '%s\n' "${options[@]}" | 
            fzf --reverse \
                --preview 'display_preview "$(echo {} | sed '\''s/^\[[^]]*\] //'\'')"' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label='Pacman Configuration' \
                --header "Pacman Configuration Menu. Alt-[ decrease preview size, Alt-] increase.
(Use arrow keys and Enter to select, Ctrl+C to Exit)" \
                --bind 'ctrl-c:abort' \
                --bind "alt-]:execute-silent(echo \$(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --bind "alt-[:execute-silent(echo \$(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
                --no-info \
                --height $menu_height \
                --layout=reverse-list)

        if [[ -z "$selected_option" ]]; then
            if [[ $(cat "$resize_flag") -eq 1 ]]; then
                echo 0 > "$resize_flag"
                continue
            else
                return
            fi
        fi

        case "$selected_option" in
            "[EDIT] "*)
                local option=${selected_option#"[EDIT] "}
                edit_pacman_option "$option"
                ;;
            "[TOGGLE] "*)
                local option=${selected_option#"[TOGGLE] "}
                toggle_pacman_option_with_confirmation "$option"
                ;;
            "[ACTION] Add New Repository")
                add_repository
                ;;
            "[ACTION] Manage Repositories")
                manage_repositories
                ;;
            "[ACTION] Edit pacman.conf directly")
                edit_pacman_conf_directly
                ;;
            "Return to Main Menu")
                return
                ;;
        esac
    done
}

# Function to edit pacman.conf directly
edit_pacman_conf_directly() {
    echo "Opening pacman.conf for editing..."
    
    # Check if we're in a graphical environment
    if [ -n "$DISPLAY" ]; then
        # Try to open with default graphical editor
        if command -v xdg-open > /dev/null; then
            sudo -E xdg-open /etc/pacman.conf
        elif command -v gio > /dev/null; then
            sudo -E gio open /etc/pacman.conf
        elif command -v gvfs-open > /dev/null; then
            sudo -E gvfs-open /etc/pacman.conf
        else
            echo "Unable to detect a graphical editor. Falling back to terminal editor."
            use_terminal_editor
        fi
    else
        use_terminal_editor
    fi
    
    echo "Editing complete. Returning to menu."
}

# Function to get recently installed packages
get_recent_installs() {
    tac /var/log/pacman.log | grep '^\[.*\] \[ALPM\] installed' | awk '{print $4}' | sed 's/[()]//g' | awk '!seen[$0]++' | head -n 15
}

# Function to get recently updated packages
get_recent_updates() {
    tac /var/log/pacman.log | grep '^\[.*\] \[ALPM\] upgraded' | awk '{print $4}' | sed 's/[()]//g' | awk '!seen[$0]++' | head -n 15
}

# Function to get recently removed packages
get_recent_removals() {
    tac /var/log/pacman.log | grep '^\[.*\] \[ALPM\] removed' | awk '{print $4}' | sed 's/[()]//g' | awk '!seen[$0]++' | head -n 15
}

# Function to use terminal-based editors
use_terminal_editor() {
    if command -v nano > /dev/null; then
        sudo nano /etc/pacman.conf
    elif command -v micro > /dev/null; then
        sudo micro /etc/pacman.conf
    elif command -v vim > /dev/null; then
        sudo vim /etc/pacman.conf
    elif command -v vi > /dev/null; then
        sudo vi /etc/pacman.conf
    else
        echo "No suitable editor found. Please manually edit /etc/pacman.conf."
        return 1
    fi
}

# Export functions so they're available to subshells
export -f display_preview
export -f get_option_description
export -f display_pacman_conf
export -f edit_pacman_option
export -f toggle_pacman_option
export -f toggle_repository
export -f manage_repositories
export -f add_repository
export -f pacman_config_menu
export -f get_recent_updates
export -f get_recent_installs
export -f get_recent_removals
export -f edit_pacman_conf_directly
export -f use_terminal_editor

# Manager Function
manager() {
    local options=(
        "Install Packages"
        "Remove Packages"
        "Update Packages"
        "Downgrade Package"
        "Clean Orphans"
        "Clear Package Cache"
        "Dependencies"
        "Pacman Configuration"
        "Exit"
    )
    local header_height=8
    local menu_height=$(($(tput lines) - $header_height - 1))
    local preview_width
    local selected_option
    local preview_file="/tmp/spm_preview_width"
    local resize_flag="/tmp/spm_resize_flag"

    # Function to handle exit
    exit_script() {
        clear
        echo "Exiting SPM - Simple Package Manager. Goodbye!"
        exec sh -c 'exit 0'
    	}

    while true; do
        clear
        print_header
        preview_width=$(get_preview_width)
        
        selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse --preview-label='Pacman Log' \
            --preview '
                bold=$(tput bold)
                normal=$(tput sgr0)
                echo "${bold}Recently updated packages:${normal}"
                get_recent_updates 15
                echo
                echo "${bold}Recently installed packages:${normal}"
                get_recent_installs 15
                echo
                echo "${bold}Recently removed packages:${normal}"
                get_recent_removals 15
            ' \
            --preview-window="right:${preview_width}%:wrap" \
            --header "$(printf 'Alt-[ move preview left, Alt-] move preview right\nPress Enter to select a function (Ctrl+C to Exit)')" \
            --bind 'ctrl-c:abort' \
            --bind "alt-]:execute-silent(echo $(($(cat $preview_file) - 10 < 10 ? 10 : $(cat $preview_file) - 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
            --bind "alt-[:execute-silent(echo $(($(cat $preview_file) + 10 > 90 ? 90 : $(cat $preview_file) + 10)) > $preview_file && echo 1 > $resize_flag)+abort" \
            --no-info \
            --height $menu_height \
            --layout=reverse-list)

        # Check if we need to exit or if it was just a resize operation
        if [[ -z "$selected_option" ]]; then
            if [[ $(cat "$resize_flag") -eq 1 ]]; then
                # It was a resize operation, reset the flag and continue
                echo 0 > "$resize_flag"
                continue
            else
                # It was an exit command
                exit_script
            fi
        fi

        case "$selected_option" in
            "Install Packages") install ;;
            "Remove Packages") remove ;;
            "Update Packages") update ;;
            "Downgrade Package") downgrade ;;
            "Clean Orphans") orphan ;;
            "Clear Package Cache") clear_cache ;;
            "Dependencies") dependencies_menu ;;
            "Pacman Configuration") pacman_config_menu ;;
            "Exit") exit_script ;;
        esac
    done
}

# Export functions if the script is being sourced
if [ $sourced -eq 1 ]; then
    export -f update install remove orphan downgrade clear_cache show_help manager dependencies_menu pacman_config_menu
fi

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
