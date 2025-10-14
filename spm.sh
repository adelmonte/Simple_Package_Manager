#!/bin/bash

# SPM - Simple Package Manager
# Dependencies: fzf (0.58.0+), yay

# Check if the script is being sourced
(return 0 2>/dev/null) && sourced=1 || sourced=0

# Define cache file paths
UPDATE_CACHE_FILE="/var/cache/spm/update-cache.txt"
DETAILED_UPDATE_CACHE_FILE="/var/cache/spm/detailed-update-cache.txt"

# Function to ensure the SPM cache directory exists with proper permissions
ensure_spm_var_dir() {
    local dir="/var/cache/spm"
    if [[ ! -d "$dir" ]]; then
        sudo mkdir -p "$dir"
    fi
    if [[ ! -w "$dir" ]]; then
        sudo chmod 777 "$dir"
    fi
}

ensure_spm_var_dir

clear_screen() {
    clear
    print_header
}

get_preview_width() {
    local preview_file="/var/cache/spm/preview_width"
    if [[ ! -f "$preview_file" ]]; then
        echo "60" > "$preview_file"
    fi
    cat "$preview_file"
}

get_pacman_cache_size() {
    local cache_dir="/var/cache/pacman/pkg"
    local size=$(find "$cache_dir" -type f -name "*.pkg.tar*" -print0 2>/dev/null | du -ch --files0-from=- 2>/dev/null | tail -n 1 | cut -f1)
    if [[ -z "$size" || "$size" == "0" || "$size" == "0B" ]]; then
        echo "0"
    else
        echo "$size"
    fi
}

get_yay_cache_size() {
    local cache_dir="$HOME/.cache/yay"
    local size=$(find "$cache_dir" -type f \( -name "*.pkg.tar*" -o -name "*.src.tar.gz" \) -print0 2>/dev/null | du -ch --files0-from=- 2>/dev/null | tail -n 1 | cut -f1)
    if [[ -z "$size" || "$size" == "0" || "$size" == "0B" ]]; then
        echo "0"
    else
        echo "$size"
    fi
}

print_header() {
    local packages=$(pacman -Q | wc -l)
    local updates=$(cat "$UPDATE_CACHE_FILE" 2>/dev/null || echo "0")
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

show_help() {
    clear_screen
    echo "Usage: spm [options] [arguments]"
    echo
    echo "Options:"
    echo "  -u, update        Update packages"
    echo "  -i, install       Install packages"
    echo "  -r, remove        Remove packages"
    echo "  -o, orphan        Clean orphaned and unneeded packages"
    echo "  -d, downgrade     Downgrade a package"
    echo "  -c, cache         Clear package cache"
    echo "  -h, --help        Display this help message"
    echo
    echo "Examples:"
    echo "  spm -i fzf        Install package"
    echo "  spm -r fzf        Remove package"
    echo "  spm -u            Update packages"
    echo "  spm -o            Clean orphaned packages"
    echo "  spm -d            Downgrade a package"
    echo "  spm -c            Clear package cache"
    echo
    echo "If no option is provided, the interactive menu will be launched."
    echo
    echo "Optional Shell Integration for Standalone Commands:"
    echo
    echo "  Bash: echo 'source /usr/bin/spm' >> ~/.bashrc"
    echo "  Fish: echo 'source /usr/share/fish/vendor_functions.d/spm.fish' >> ~/.config/fish/config.fish"
    echo
    echo "To enable automatic update checking:"
    echo "  systemctl enable --now spm_updates.timer"
    echo
}

handle_return() {
    echo
    read -p "Press Ctrl+C to exit or any other key to return to the Main Menu. " -n 1 -s -r key
    if [[ "$key" == $'\x03' ]]; then
        exit 0
    else
        clear_screen
        manager
    fi
}

get_recent_installs() {
    tac /var/log/pacman.log 2>/dev/null | grep '^\[.*\] \[ALPM\] installed' | awk '{print $4}' | sed 's/[()]//g' | awk '!seen[$0]++' | head -n "${1:-15}"
}

get_recent_updates() {
    tac /var/log/pacman.log 2>/dev/null | grep '^\[.*\] \[ALPM\] upgraded' | awk '{print $4}' | sed 's/[()]//g' | awk '!seen[$0]++' | head -n "${1:-15}"
}

get_recent_removals() {
    tac /var/log/pacman.log 2>/dev/null | grep '^\[.*\] \[ALPM\] removed' | awk '{print $4}' | sed 's/[()]//g' | awk '!seen[$0]++' | head -n "${1:-15}"
}

update() {
    clear_screen
    
    if [ -t 0 ]; then
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"
        
        echo 0 > "$resize_flag"
        
        local menu_height
        if [ -n "$LINES" ]; then
            menu_height=$((LINES - 10))
        else
            menu_height=15
        fi
    else
        local preview_width=50
        local menu_height=15
    fi
    
    while true; do
        local selected_option=$(printf '%s\n' \
            "Quick Full Update - Auto-yes all" \
            "Full Update - Review all changes" \
            "yay System Update - Review changes" \
            "Flatpak Update - Review changes" \
            "Update AUR Development Packages" \
            "Return to Main Menu" | 
            fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Update Packages " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    
                    echo -e "${bold}${cyan}Update Information${normal}"
                    echo
                    echo -e "${bold}Command to execute:${normal}"
                    case {} in
                        "Quick Full Update"*)    echo "yes | yay && flatpak update --assumeyes" ;;
                        "Full Update"*)          echo "yay && flatpak update" ;;
                        "yay System Update"*)    echo "yay -Syu" ;;
                        "Flatpak Update"*)       echo "flatpak update" ;;
                        "Update AUR"*)           echo "yay -Sua --devel" ;;
                        *)                       echo "No command" ;;
                    esac
                    echo
                    echo -e "${bold}Upgradable Packages:${normal}"
                    echo
                    cat "'$DETAILED_UPDATE_CACHE_FILE'" 2>/dev/null || echo "No update information available."
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Update Information ' \
                --header="Select an update option
Alt+[ increase preview | Alt+] decrease preview | Enter to confirm | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --height=$menu_height \
                --ansi)

        if [[ -z "$selected_option" ]]; then
            if [ -t 0 ] && [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
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
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                ;;
            "Full Update"*)
                echo "Performing full update..."
                yay
                flatpak update
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                ;;
            "yay System Update"*)
                echo "Updating yay packages..."
                yay -Syu
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                ;;
            "Flatpak Update"*)
                echo "Updating Flatpak apps..."
                flatpak update
                ;;
            "Update AUR"*)
                echo "Checking AUR development packages for updates..."
                yay -Sua --devel
                ;;
            "Return to Main Menu")
                return
                ;;
        esac
        
        handle_return
        break
    done
}

install() {
    local exit_function=false
    while ! $exit_function; do
        clear_screen
        echo "Install Packages"
        echo "----------------"
        echo "Loading packages... This may take a moment."
        
        local search_query="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        local repo_order=$(grep '^\[.*\]' /etc/pacman.conf | grep -v '^\[options\]' | sed 's/[][]//g')
        local package_list=$(yay -Sl 2>/dev/null)
        local installed_packages=$(pacman -Qq 2>/dev/null)

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
                version = "unknown"
            }
            priority = (repo in repo_priority) ? repo_priority[repo] : (repo == "aur" ? 998 : 999)
            installed_priority = (package in is_installed) ? 0 : 1
            status = (package in is_installed) ? "[INSTALLED]" : ""
            if (repo == "aur") {
                printf "%01d %03d %-50s %-20s %s\n", installed_priority, priority, package, repo, status
            } else {
                printf "%01d %03d %-50s %-20s %s\n", installed_priority, priority, package " " version, repo, status
            }
        }' | sort -n | cut -d' ' -f3-)

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_packages=$(echo "$sorted_package_list" | fzf --multi --reverse \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Install Packages " \
                --preview "
                    bold=\$(tput bold)
                    normal=\$(tput sgr0)
                    cyan=\$(tput setaf 6)
                    green=\$(tput setaf 2)
                    yellow=\$(tput setaf 3)
                    
                    pkg_name={1}
                    
                    if pacman -Qi \$pkg_name &>/dev/null; then
                        echo -e \"\${bold}\${green}● Package Status: INSTALLED\${normal}\"
                        echo
                        echo -e \"\${bold}\${cyan}Package Information\${normal}\"
                        yay -Qi \$pkg_name
                        echo
                        echo -e \"\${bold}Installed Files:\${normal}\"
                        pacman -Ql \$pkg_name | grep -v '/\$' | cut -d' ' -f2- | head -50
                    else
                        echo -e \"\${bold}\${yellow}○ Package Status: NOT INSTALLED\${normal}\"
                        echo
                        echo -e \"\${bold}\${cyan}Package Information\${normal}\"
                        yay -Si \$pkg_name
                    fi
                " \
                --preview-window="right:$preview_width%:wrap" \
                --preview-label=' Package Information ' \
                --header="Select packages to install
Alt+[ increase preview | Alt+] decrease preview | Tab to select | Enter to confirm | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --tiebreak=index \
                --ansi \
                ${search_query:+-q "$search_query"} \
                | awk '{print $1}')

            if [[ -z "$selected_packages" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    exit_function=true
                    break
                fi
            fi

            if [ -n "$selected_packages" ]; then
                echo "The following packages will be installed:"
                echo "$selected_packages" | sed 's/^/  → /'
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                case $confirm in
                    [Nn]* ) echo "Operation cancelled.";;
                    * ) yay -S $selected_packages;;
                esac
            fi

            echo
            read -p "Press Ctrl+C to exit or any other key to return to package selection. " -n 1 -s -r key
            if [[ "$key" == $'\x03' ]]; then
                exit_function=true
            fi
            break
        done
    done

    if [ $sourced -eq 0 ]; then
        handle_return
    fi
}

remove() {
    local exit_function=false
    while ! $exit_function; do
        clear_screen
        echo "Remove Packages"
        echo "---------------"
        
        local search_query="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_packages=$(pacman -Qq | fzf --multi --reverse \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Remove Packages " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    red=$(tput setaf 1)
                    yellow=$(tput setaf 3)
                    
                    echo -e "${bold}${red}⚠ Package Information: {1}${normal}"
                    echo
                    echo -e "${bold}${cyan}Package Details${normal}"
                    yay -Qi {1}
                    echo
                    echo -e "${bold}${yellow}Required By:${normal}"
                    pacman -Qi {1} | grep "Required By" | cut -d":" -f2
                    echo
                    echo -e "${bold}Installed Files:${normal}"
                    pacman -Ql {1} | grep -v "/$" | cut -d" " -f2- | head -100
                ' \
                --preview-window="right:$preview_width%:wrap" \
                --preview-label=' Package Information ' \
                --header="Select packages to remove
Alt+[ increase preview | Alt+] decrease preview | Tab to select | Enter to confirm | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --ansi \
                ${search_query:+-q "$search_query"})

            if [[ -z "$selected_packages" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    exit_function=true
                    break
                fi
            fi

            if [ -n "$selected_packages" ]; then
                echo "The following packages will be removed:"
                echo "$selected_packages" | sed 's/^/  → /'
                echo
                
                echo "Package Removal Options:"
                echo "------------------------"
                
                local pacman_args
                while true; do
                    echo "1) Remove package, dependencies, config files, and cascade dependencies -Rnsc [Recommended]"
                    echo "2) Remove package, dependencies, and configuration files -Rns"
                    echo "3) Remove package and configuration files -Rn"
                    echo "4) Remove package and its dependencies -Rs"
                    echo "5) Remove package only -R"
                    echo "6) Remove package and ignore dependencies DANGEROUS -Rdd"
                    echo "7) Remove package, ignore dependencies, and remove config files DANGEROUS -Rddn"
                    echo "8) Cancel removal"
                    echo
                    read -p "Enter option 1-8 [1]: " remove_option

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
            echo
            read -p "Press Ctrl+C to exit or any other key to return to the Main Menu. " -n 1 -s -r key
            if [[ "$key" == $'\x03' ]]; then
                exit_function=true
            fi
        fi
    done

    if [ $sourced -eq 0 ]; then
        handle_return
    fi
}

explore_dependencies() {
    while true; do
        clear_screen
        echo "Explore Dependencies"
        echo "--------------------"
        echo "Browse packages and examine their dependency relationships."
        echo "Press Ctrl+C to return to the Dependencies Menu."
        echo

        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            
            local package_list=$(pacman -Qd | awk '{print $1}')
            local selected_package=$(echo "$package_list" | fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Explore Dependencies " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    green=$(tput setaf 2)
                    yellow=$(tput setaf 3)
                    
                    echo -e "${bold}${cyan}Package: {1}${normal}"
                    echo
                    echo -e "${bold}Description:${normal}"
                    pacman -Qi {1} | grep "Description" | cut -d":" -f2-
                    echo
                    echo -e "${bold}${green}Required By - packages that depend on this:${normal}"
                    req_by=$(pacman -Qi {1} | grep "Required By" | cut -d":" -f2-)
                    if [[ "$req_by" == *"None"* ]]; then
                        echo "  None"
                    else
                        echo "$req_by" | tr " " "\n" | sed "s/^/  /"
                    fi
                    echo
                    echo -e "${bold}${yellow}Dependencies of this package:${normal}"
                    pacman -Qi {1} | grep "Depends On" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Dependency Information ' \
                --header="Select a dependency package to explore
Alt+[ increase preview | Alt+] decrease preview | Enter to view details | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --ansi)
            
            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    return
                fi
            fi

            clear_screen
            echo "Package: $selected_package"
            echo "Description: $(pacman -Qi $selected_package | grep "Description" | cut -d":" -f2-)"
            echo
            echo "Required By - packages that depend on this:"
            pacman -Qi $selected_package | grep "Required By" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            echo "Dependencies of this package:"
            pacman -Qi $selected_package | grep "Depends On" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            read -p "Press any key to continue exploring or Ctrl+C to return. " -n 1 -s -r
            break
        done
    done
}

sort_packages() {
    while true; do
        clear_screen
        local temp_file=$(mktemp)
        echo "Analyzing dependencies... This may take a moment."
        
        pacman -Qq | while read -r pkg; do
            local dep_count=$(pactree -d 1 -u "$pkg" 2>/dev/null | tail -n +2 | wc -l)
            printf "%03d %s\n" "$dep_count" "$pkg"
        done | sort -rn > "$temp_file"
        
        echo

        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            local selected_package=$(cat "$temp_file" | fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    echo -e "${bold}Package: {2}${normal}"
                    echo -e "${bold}Direct Dependencies: {1}${normal}"
                    echo
                    echo -e "${bold}Description:${normal}"
                    pacman -Qi {2} | grep "Description" | cut -d":" -f2-
                    echo
                    echo -e "${bold}Direct Dependencies:${normal}"
                    pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed "s/^/  /"
                    echo
                    echo -e "${bold}Optional Dependencies:${normal}"
                    pacman -Qi {2} | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Package Dependencies ' \
                --header-border=line \
                --header="Packages sorted by direct dependency count - highest first
Alt+[ increase preview | Alt+] decrease preview | Enter to select | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --ansi \
                | awk '{print $2}')
            
            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    rm "$temp_file"
                    return
                fi
            fi

            clear_screen
            echo "Package: $selected_package"
            echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2-)"
            echo
            local dep_count=$(pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | wc -l)
            echo "Direct Dependencies: $dep_count"
            pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2
            echo
            echo "Optional Dependencies:"
            pacman -Qi "$selected_package" | grep -A 100 "Optional Deps" | sed -n "/Optional Deps/,/^$/p" | sed "1d;$d" | sed "s/^/  /"
            echo
            echo "Required By:"
            pacman -Qi "$selected_package" | grep "Required By" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            read -p "Press any key to continue or Ctrl+C to return. " -n 1 -s -r
            break
        done
        rm "$temp_file"
    done
}

sort_packages_by_exclusive_deps() {
    while true; do
        clear_screen
        local temp_file=$(mktemp)
        echo "Analyzing exclusive dependencies... This may take a while."
        
        pacman -Qq | while read -r pkg; do
            local exclusive_deps=$(pacman -Rsp "$pkg" 2>/dev/null | grep -v "^$pkg")
            local exclusive_dep_count=$(echo "$exclusive_deps" | grep -c '^' 2>/dev/null || echo 0)
            printf "%03d %s\n" "$exclusive_dep_count" "$pkg"
        done | sort -rn > "$temp_file"
        
        echo

        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            local selected_package=$(cat "$temp_file" | fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    echo -e "${bold}Package: {2}${normal}"
                    echo -e "${bold}Exclusive Dependencies: {1}${normal}"
                    echo -e "${bold}Dependencies that would be removed with this package${normal}"
                    echo
                    echo -e "${bold}Description:${normal}"
                    pacman -Qi {2} | grep "Description" | cut -d":" -f2-
                    echo
                    echo -e "${bold}All Direct Dependencies:${normal}"
                    pactree -d 1 -u {2} 2>/dev/null | tail -n +2 | sed "s/^/  /"
                    echo
                    echo -e "${bold}Exclusive Dependencies List:${normal}"
                    pacman -Rsp {2} 2>/dev/null | grep -v "^{2}" | sed "s/^/  /" | head -20
                    echo
                    echo -e "${bold}Required By:${normal}"
                    req_by=$(pacman -Qi {2} | grep "Required By" | cut -d":" -f2-)
                    if [[ "$req_by" == *"None"* ]]; then
                        echo "  None"
                    else
                        echo "$req_by" | tr " " "\n" | sed "s/^/  /"
                    fi
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Exclusive Dependencies Analysis ' \
                --header-border=line \
                --header="Packages sorted by exclusive dependencies
Alt+[ increase preview | Alt+] decrease preview | Enter to select | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --ansi \
                | awk '{print $2}')
            
            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    rm "$temp_file"
                    return
                fi
            fi

            clear_screen
            echo "Package: $selected_package"
            echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2-)"
            echo
            local all_deps_count=$(pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | wc -l)
            echo "All Direct Dependencies: $all_deps_count"
            pactree -d 1 -u "$selected_package" 2>/dev/null | tail -n +2 | sed "s/^/  /"
            echo
            local exclusive_count=$(pacman -Rsp "$selected_package" 2>/dev/null | grep -v "^$selected_package" | wc -l)
            echo "Exclusive Dependencies - would be removed: $exclusive_count"
            pacman -Rsp "$selected_package" 2>/dev/null | grep -v "^$selected_package" | sed "s/^/  /" | head -30
            echo
            echo "Required By:"
            pacman -Qi "$selected_package" | grep "Required By" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            pacman -Qi "$selected_package" | grep -E "Build Date|Install Date|Install Reason"
            echo
            read -p "Press any key to continue or Ctrl+C to return. " -n 1 -s -r
            break
        done
        rm "$temp_file"
    done
}

dependencies_menu() {
    while true; do
        clear_screen

        local options=("Explore Dependencies" "Sort by # of Dependencies" "Sort by # of Exclusive Dependencies" "Return to Main Menu")
        local header_height=8
        local menu_height=$(($(tput lines) - $header_height - 1))

        local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
            --style=full:line \
			--preview-border=rounded \
            --header-border=line \
            --border-label=" Dependencies Menu " \
            --preview '
                bold=$(tput bold)
                normal=$(tput sgr0)
                cyan=$(tput setaf 6)
                
                echo -e "${bold}${cyan}Function Information${normal}"
                echo
                case {} in
                    "Explore Dependencies")
                        echo -e "${bold}Function: Explore Dependencies${normal}"
                        echo
                        echo "Browse dependency packages and examine their relationships."
                        echo
                        echo -e "${bold}What this does:${normal}"
                        echo "• Lists all packages installed as dependencies"
                        echo "• Shows which packages require each dependency"
                        echo "• Displays the dependencies of each package"
                        echo
                        echo -e "${bold}Use case:${normal}"
                        echo "Understanding why a package is installed and what depends on it."
                        ;;
                    "Sort by # of Dependencies")
                        echo -e "${bold}Function: Sort by Number of Dependencies${normal}"
                        echo
                        echo "Sort packages by the number of direct dependencies they have."
                        echo
                        echo -e "${bold}What this does:${normal}"
                        echo "• Analyzes all installed packages"
                        echo "• Counts direct dependencies for each"
                        echo "• Sorts from highest to lowest"
                        echo
                        echo -e "${bold}Use case:${normal}"
                        echo "Identifying complex packages with many dependencies."
                        ;;
                    "Sort by # of Exclusive Dependencies")
                        echo -e "${bold}Function: Sort by Exclusive Dependencies${normal}"
                        echo
                        echo "Sort packages by exclusive dependencies."
                        echo
                        echo -e "${bold}What this does:${normal}"
                        echo "• Analyzes what would be removed with each package"
                        echo "• Counts dependencies unique to each package"
                        echo "• Sorts from highest to lowest"
                        echo
                        echo -e "${bold}Use case:${normal}"
                        echo "Finding packages that can be cleanly removed with minimal impact."
                        ;;
                    *)
                        echo "Return to the main menu"
                        ;;
                esac
            ' \
            --preview-window="right:50%:wrap" \
            --preview-label=' Function Description ' \
            --header="Dependencies Menu - Select a function
Enter to confirm | Ctrl+C to return" \
            --bind 'ctrl-c:abort' \
            --height=$menu_height \
            --ansi)

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

orphan() {
    while true; do
        clear_screen
        
        if [ -t 0 ]; then
            local preview_width=$(get_preview_width)
            local preview_file="/var/cache/spm/preview_width"
            local resize_flag="/var/cache/spm/resize_flag"

            echo 0 > "$resize_flag"

            local options=(
                "Quick Remove All - Auto-yes for both orphaned and unneeded"
                "Remove Orphaned Packages Only - installed as dependencies, no longer needed"
                "Remove Unneeded Packages Only - dependencies not required by explicitly installed packages"
                "Review and Remove Both Orphaned and Unneeded"
                "Return to Main Menu"
            )

            local header_height=7
            local menu_height=$(($(tput lines) - $header_height - 1))

            while true; do
                preview_width=$(cat "$preview_file")
                
                local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                    --style=full:line \
					--preview-border=rounded \
                    --border-label=" Clean Orphans " \
                    --header-border=line \
                    --preview '
                        bold=$(tput bold)
                        normal=$(tput sgr0)
                        cyan=$(tput setaf 6)
                        yellow=$(tput setaf 3)
                        red=$(tput setaf 1)
                        
                        echo -e "${bold}${cyan}Clean Orphans Information${normal}"
                        echo
                        echo -e "${bold}Command to execute:${normal}"
                        case {} in
                            "Quick Remove All"*)
                                echo "sudo pacman -Rns \$(pacman -Qdtq) --noconfirm"
                                echo "sudo pacman -Rsu \$(pacman -Qqd) --noconfirm"
                                ;;
                            "Remove Orphaned"*)
                                echo "sudo pacman -Rns \$(pacman -Qdtq)"
                                ;;
                            "Remove Unneeded"*)
                                echo "sudo pacman -Rsu \$(pacman -Qqd)"
                                ;;
                            "Review and Remove Both"*)
                                echo "sudo pacman -Rns \$(pacman -Qdtq)"
                                echo "sudo pacman -Rsu \$(pacman -Qqd)"
                                ;;
                            *)
                                echo "No command to execute"
                                ;;
                        esac
                        echo
                        echo -e "${bold}${yellow}Orphaned Packages:${normal}"
                        echo "Installed as dependencies but no longer required"
                        orphans=$(pacman -Qdtq 2>/dev/null)
                        orphan_count=$(echo "$orphans" | grep -c . 2>/dev/null || echo 0)
                        echo "Count: $orphan_count"
                        if [ -n "$orphans" ]; then
                            echo "$orphans" | sed "s/^/  /" | head -20
                            if [ $orphan_count -gt 20 ]; then
                                echo "  ... and $((orphan_count - 20)) more"
                            fi
                        else
                            echo "  None found"
                        fi
                        echo
                        echo -e "${bold}${red}Unneeded Packages:${normal}"
                        echo "Dependencies not required by explicitly installed packages"
                        unneeded=$(pacman -Qqd 2>/dev/null | xargs pacman -Rsu --print 2>/dev/null | grep "^  " | awk "{print \$1}")
                        unneeded_count=$(echo "$unneeded" | grep -c . 2>/dev/null || echo 0)
                        echo "Count: $unneeded_count"
                        if [ -n "$unneeded" ]; then
                            echo "$unneeded" | sed "s/^/  /" | head -20
                            if [ $unneeded_count -gt 20 ]; then
                                echo "  ... and $((unneeded_count - 20)) more"
                            fi
                        else
                            echo "  None found"
                        fi
                    ' \
                    --preview-window="right:${preview_width}%:wrap" \
                    --preview-label=' Orphaned and Unneeded Packages ' \
                    --header="Select an option to clean packages
Alt+[ increase preview | Alt+] decrease preview | Enter to confirm | Ctrl+C to return" \
                    --bind 'ctrl-c:abort' \
                    --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                    --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                    --height="$menu_height" \
                    --ansi)

                if [[ -z "$selected_option" ]]; then
                    if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                        echo 0 > "$resize_flag"
                        continue
                    else
                        return
                    fi
                fi
                
                break
            done

            if [ "$selected_option" = "Return to Main Menu" ]; then
                return
            fi

            process_orphan_option "$selected_option"
            
            echo
            read -p "Press any key to continue... " -n 1 -s -r
        else
            echo "Performing quick remove of orphaned and unneeded packages..."
            sudo pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null
            sudo pacman -Rsu $(pacman -Qqd) --noconfirm 2>/dev/null
            echo "Removal complete."
            return
        fi
    done
}

process_orphan_option() {
    local option="$1"
    case "$option" in
        "Quick Remove All"*)
            echo "Performing quick removal..."
            sudo pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null
            sudo pacman -Rsu $(pacman -Qqd) --noconfirm 2>/dev/null
            echo "Removal complete."
            ;;
        "Remove Orphaned"*)
            local orphans=$(pacman -Qdtq 2>/dev/null)
            if [ -n "$orphans" ]; then
                echo "The following orphaned packages will be removed:"
                echo "$orphans" | sed 's/^/  → /'
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                    sudo pacman -Rns $orphans
                else
                    echo "No orphaned packages were removed."
                fi
            else
                echo "No orphaned packages found."
            fi
            ;;
        "Remove Unneeded"*)
            local unneeded=$(pacman -Qqd 2>/dev/null | xargs pacman -Rsu --print 2>/dev/null | grep "^  " | awk '{print $1}')
            if [ -n "$unneeded" ]; then
                echo "The following unneeded packages will be removed:"
                echo "$unneeded" | sed 's/^/  → /'
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                    sudo pacman -Rsu $(pacman -Qqd) 2>/dev/null
                else
                    echo "No unneeded packages were removed."
                fi
            else
                echo "No unneeded packages found."
            fi
            ;;
        "Review and Remove Both"*)
            local orphans=$(pacman -Qdtq 2>/dev/null)
            local unneeded=$(pacman -Qqd 2>/dev/null | xargs pacman -Rsu --print 2>/dev/null | grep "^  " | awk '{print $1}')
            
            if [ -n "$orphans" ] || [ -n "$unneeded" ]; then
                echo "The following packages will be removed:"
                if [ -n "$orphans" ]; then
                    echo
                    echo "Orphaned packages:"
                    echo "$orphans" | sed 's/^/  → /'
                fi
                if [ -n "$unneeded" ]; then
                    echo
                    echo "Unneeded packages:"
                    echo "$unneeded" | sed 's/^/  → /'
                fi
                echo
                read -p "Do you want to proceed? [Y/n] " confirm
                if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                    [ -n "$orphans" ] && sudo pacman -Rns $orphans
                    [ -n "$unneeded" ] && sudo pacman -Rsu $(pacman -Qqd) 2>/dev/null
                else
                    echo "No packages were removed."
                fi
            else
                echo "No orphaned or unneeded packages found."
            fi
            ;;
    esac
}


downgrade() {
    clear_screen
    echo "Downgrade Packages"
    echo "------------------"
    
    local packages="$1"
    local preview_width=$(get_preview_width)
    local preview_file="/var/cache/spm/preview_width"
    local resize_flag="/var/cache/spm/resize_flag"

    echo 0 > "$resize_flag"
    
    if [ -z "$packages" ]; then
        while true; do
            preview_width=$(cat "$preview_file")
            
            packages=$(pacman -Qq | fzf --reverse --multi \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Downgrade Packages " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    yellow=$(tput setaf 3)
                    
                    echo -e "${bold}${yellow}⬇ Downgrade: {}${normal}"
                    echo
                    echo -e "${bold}${cyan}Current Package Version${normal}"
                    pacman -Qi {} 2>/dev/null || echo "Package not found"
                ' \
                --preview-window="right:$preview_width%:wrap" \
                --preview-label=' Current Package Version ' \
                --header="Select packages to downgrade
Alt+[ increase preview | Alt+] decrease preview | Tab to select | Enter to confirm | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --ansi)
            
            if [[ -z "$packages" ]]; then
                [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]] && { echo 0 > "$resize_flag"; continue; }
                return
            else
                break
            fi
        done
    fi

    for package in $packages; do
        echo "Searching for previous versions of $package..."

        if ! pacman -Qi "$package" > /dev/null 2>&1; then
            echo "Package $package is not installed. Skipping..."
            continue
        fi

        versions=$(ls /var/cache/pacman/pkg/${package}-[0-9]*.pkg.tar.* 2>/dev/null | sort -V -r)

        if [ -z "$versions" ]; then
            echo "No cached versions found for $package."
            read -p "Do you want to search the Arch Linux Archive for $package? [Y/n] " search_ala
            if [[ ! $search_ala =~ ^[Nn]o?$ ]]; then
                ala_versions=$(curl -s "https://archive.archlinux.org/packages/${package:0:1}/$package/" 2>/dev/null | grep -o "$package-[0-9].*xz" | sort -V -r)
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

        while true; do
            preview_width=$(cat "$preview_file")
            selected_version=$(echo "$versions" | fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Select Version for $package " \
                --preview "
                    bold=\$(tput bold)
                    normal=\$(tput sgr0)
                    cyan=\$(tput setaf 6)
                    
                    echo -e \"\${bold}\${cyan}Version Information\${normal}\"
                    echo -e \"\${bold}Version: {}\${normal}\"
                    echo
                    echo -e \"\${bold}Package Details:\${normal}\"
                    if [[ {} == http* ]]; then
                        echo 'Version from Arch Linux Archive'
                    else
                        pacman -Qip {} 2>/dev/null || echo 'Details not available'
                    fi
                " \
                --preview-window="right:$preview_width%:wrap" \
                --preview-label=' Version Information ' \
                --header="Select a version to downgrade $package
Alt+[ increase preview | Alt+] decrease preview | Enter to confirm | Ctrl+C to skip" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --ansi)

            if [[ -z "$selected_version" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    echo "No version selected for $package. Skipping..."
                    break
                fi
            else
                break
            fi
        done

        if [ -n "$selected_version" ]; then
            if [[ $selected_version == http* ]] || [[ $selected_version == *".pkg.tar"* && ! -f "$selected_version" ]]; then
                local filename=$(basename "$selected_version")
                echo "Downloading $filename from Arch Linux Archive..."
                wget -q --show-progress "https://archive.archlinux.org/packages/${package:0:1}/$package/$filename" -O "/tmp/$filename"
                if [ -f "/tmp/$filename" ]; then
                    sudo pacman -U "/tmp/$filename"
                    rm "/tmp/$filename"
                else
                    echo "Download failed for $package."
                fi
            else
                sudo pacman -U "$selected_version"
            fi
            echo "Downgrade completed for $package."
        fi
    done
    
    echo "All selected packages have been processed."
    handle_return
}

clear_cache() {
    while true; do
        clear_screen
        
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        local options=(
            "Quick Clear All - Auto-yes for pacman and yay"
            "Clear ALL Cache - Including Latest Versions for pacman and yay"
            "Clear Old Versions - Keep only latest installed version"
            "Clear Yay Cache Only"
            "Return to Main Menu"
        )

        local header_height=7
        local menu_height=$(($(tput lines) - $header_height - 1))

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" Clear Package Cache " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    yellow=$(tput setaf 3)
                    
                    echo -e "${bold}${cyan}Cache Clear Information${normal}"
                    echo
                    echo -e "${bold}Command to execute:${normal}"
                    case {} in
                        "Quick Clear All"*)
                            echo "sudo pacman -Sc --noconfirm"
                            echo "yay -Sc --noconfirm"
                            ;;
                        "Clear ALL Cache"*)
                            echo "sudo rm -f /var/cache/pacman/pkg/*.pkg.tar.*"
                            echo "yay -Scc --noconfirm"
                            ;;
                        "Clear Old Versions"*)
                            echo "sudo pacman -Sc"
                            ;;
                        "Clear Yay Cache"*)
                            echo "yay -Sc"
                            ;;
                        *)
                            echo "No command to execute"
                            ;;
                    esac
                    echo
                    echo -e "${bold}${yellow}Current Cache Sizes:${normal}"
                    pacman_cache=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
                    echo "Pacman cache: $pacman_cache"
                    yay_pkg_size=$(find ~/.cache/yay -name "*.pkg.tar.*" -type f 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | cut -f1)
                    if [[ -n "$yay_pkg_size" && "$yay_pkg_size" != "0" ]]; then
                        echo "Yay package cache: $yay_pkg_size"
                    else
                        echo "Yay package cache: 0"
                    fi
                    echo
                    echo -e "${bold}Pacman Cache Details:${normal}"
                    total_pkgs=$(ls -1 /var/cache/pacman/pkg/*.pkg.tar.* 2>/dev/null | wc -l)
                    unique_pkgs=$(ls -1 /var/cache/pacman/pkg/*.pkg.tar.* 2>/dev/null | sed "s/-[0-9].*$//" | sort -u | wc -l)
                    echo "Total packages: $total_pkgs"
                    echo "Unique packages: $unique_pkgs"
                    echo
                    echo -e "${bold}Disk Usage:${normal}"
                    df -h / | awk "NR==2 {print \"Used: \" \$3 \" of \" \$2 \" - \" \$5}"
                    df -h / | awk "NR==2 {print \"Available: \" \$4}"
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Cache Information ' \
                --header="Select an option to clear cache
Alt+[ increase preview | Alt+] decrease preview | Enter to confirm | Ctrl+C to return" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --height="$menu_height" \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    return
                fi
            fi
            
            break
        done

        case "$selected_option" in
            "Quick Clear All"*)
                echo "Performing quick cache clear..."
                sudo pacman -Sc --noconfirm
                yay -Sc --noconfirm
                ;;
            "Clear ALL Cache"*)
                echo "Clearing ALL package caches..."
                read -p "This will remove ALL cached packages including latest versions. Continue? [y/N] " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    sudo rm -f /var/cache/pacman/pkg/*.pkg.tar.*
                    yay -Scc --noconfirm
                else
                    echo "Operation cancelled."
                fi
                ;;
            "Clear Old Versions"*)
                echo "Clearing old package versions..."
                sudo pacman -Sc
                ;;
            "Clear Yay Cache"*)
                echo "Clearing Yay cache..."
                yay -Sc
                ;;
            "Return to Main Menu")
                return
                ;;
        esac

        local remaining_cache=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
        echo "Operation completed. Remaining pacman cache size: $remaining_cache"
        read -p "Press any key to continue... " -n 1 -s -r
    done
}

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

get_option_description() {
    case "$1" in
        "RootDir") echo "Set the default root directory for pacman to install to.";;
        "DBPath") echo "Overrides the default location of the toplevel database directory.";;
        "CacheDir") echo "Overrides the default location of the package cache directory.";;
        "LogFile") echo "Overrides the default location of the pacman log file.";;
        "GPGDir") echo "Overrides the default location of the directory containing GnuPG configuration files.";;
        "HookDir") echo "Add directories to search for alpm hooks.";;
        "HoldPkg") echo "Packages that should not be removed unless explicitly requested - space-separated.";;
        "IgnorePkg") echo "Packages that should be ignored during upgrades - space-separated.";;
        "IgnoreGroup") echo "Groups of packages to ignore during upgrades - space-separated.";;
        "Architecture") echo "Defines the system architectures pacman will use for package downloads.";;
        "XferCommand") echo "Specifies an external program to handle file downloads.";;
        "NoUpgrade") echo "Files that should never be overwritten during package installation or upgrades - space-separated.";;
        "NoExtract") echo "Files that should never be extracted from packages - space-separated.";;
        "CleanMethod") echo "Specifies how pacman cleans up old packages - KeepInstalled or KeepCurrent.";;
        "SigLevel") echo "Sets the default signature verification level.";;
        "LocalFileSigLevel") echo "Sets the signature verification level for installing local packages.";;
        "RemoteFileSigLevel") echo "Sets the signature verification level for installing remote packages.";;
"ParallelDownloads") echo "Specifies the number of concurrent download streams - recommended: 5.";;
        "UseSyslog") echo "Log action messages through syslog.";;
        "Color") echo "Automatically enable colors for terminal output.";;
        "NoProgressBar") echo "Disables progress bars during downloads.";;
        "CheckSpace") echo "Performs a check for adequate available disk space before installing packages.";;
        "VerbosePkgLists") echo "Displays name, version, and size of target packages.";;
        "DisableDownloadTimeout") echo "Disable defaults for low speed limit and timeout on downloads.";;
        "ILoveCandy") echo "Enables a playful pacman-style progress bar.";;
        "Add New Repository") echo "Add a custom repository to pacman.conf.";;
        "Manage Repositories") echo "Enable or disable multiple repositories at once.";;
        "Edit pacman.conf directly") echo "Open pacman.conf in your default text editor.";;
        "Return to Main Menu") echo "Return to the main SPM menu.";;
        *) echo "No description available.";;
    esac
}

display_preview() {
    local option="$1"
    local description=$(get_option_description "$option")
    local current_value
    
    if grep -q "^$option" /etc/pacman.conf 2>/dev/null; then
        current_value=$(grep "^$option" /etc/pacman.conf | sed 's/.*=//; s/^[[:space:]]*//' | tail -n 1)
        current_value="${current_value:-Enabled - no value}"
    elif grep -q "^#$option" /etc/pacman.conf 2>/dev/null; then
        current_value="Disabled - commented out"
    else
        current_value="Not set"
    fi
    
    local bold=$(tput bold)
    local normal=$(tput sgr0)
    
    echo -e "${bold}Option: $option${normal}"
    echo -e "${bold}Current Value:${normal} $current_value"
    echo
    echo -e "${bold}Description:${normal}"
    echo "$description"
    echo
    display_pacman_conf
}

edit_pacman_option() {
    local option="$1"
    local current_value=$(grep "^#*$option" /etc/pacman.conf 2>/dev/null | sed 's/^#*//; s/.*=//; s/^[[:space:]]*//' | tail -n 1)
    local new_value

    echo "Editing: $option"
    echo "Current value: ${current_value:-Not set}"
    echo
    echo "Description: $(get_option_description "$option")"
    echo
    echo "For multiple values, separate them with spaces."
    read -e -i "$current_value" -p "Enter new value or press Enter to keep current: " new_value

    if [ -n "$new_value" ] && [ "$new_value" != "$current_value" ]; then
        new_value_escaped=$(echo "$new_value" | sed 's/[\/&]/\\&/g')
        
        if grep -q "^#*$option" /etc/pacman.conf; then
            sudo sed -i "s|^#*$option.*|$option = $new_value_escaped|" /etc/pacman.conf
            echo "$option updated to: $new_value"
        else
            sudo sed -i "/^\[options\]/a $option = $new_value_escaped" /etc/pacman.conf
            echo "$option added with value: $new_value"
        fi
    else
        echo "No changes made to $option"
    fi
    echo
    read -p "Press any key to continue... " -n 1 -s -r
}

toggle_pacman_option_with_confirmation() {
    local option="$1"
    local current_status
    local new_status

    if grep -q "^$option" /etc/pacman.conf 2>/dev/null; then
        current_status="enabled"
        new_status="disable"
    elif grep -q "^#$option" /etc/pacman.conf 2>/dev/null; then
        current_status="disabled"
        new_status="enable"
    else
        current_status="not set"
        new_status="enable"
    fi

    echo "Option: $option"
    echo "Current status: $current_status"
    echo
    echo "Description: $(get_option_description "$option")"
    echo
    read -p "Do you want to $new_status $option? [y/N] " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        if [ "$new_status" = "enable" ]; then
            if grep -q "^#$option" /etc/pacman.conf; then
                sudo sed -i "s/^#$option/$option/" /etc/pacman.conf
            else
                sudo sed -i "/^\[options\]/a $option" /etc/pacman.conf
            fi
            echo "$option has been enabled."
        else
            sudo sed -i "s/^$option/#$option/" /etc/pacman.conf
            echo "$option has been disabled."
        fi
    else
        echo "No changes made to $option"
    fi
    echo
    read -p "Press any key to continue... " -n 1 -s -r
}

toggle_repository() {
    local repo="$1"
    if grep -q "^\[$repo\]" /etc/pacman.conf; then
        echo "Disabling repository: $repo"
        sudo sed -i "/^\[$repo\]/,/^$/s/^\([^#]\)/#\1/g" /etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo "$repo repository disabled successfully."
        else
            echo "Failed to disable $repo repository. Check sudo privileges."
        fi
    elif grep -q "^#\[$repo\]" /etc/pacman.conf; then
        echo "Enabling repository: $repo"
        sudo sed -i "/^#\[$repo\]/,/^$/s/^#//g" /etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo "$repo repository enabled successfully."
        else
            echo "Failed to enable $repo repository. Check sudo privileges."
        fi
    else
        echo "Repository $repo not found in pacman.conf"
    fi
}

manage_repositories() {
    local options=""
    
    while IFS= read -r line; do
        if [[ $line =~ ^#?\[(.*)\]$ ]]; then
            repo=$(echo "$line" | sed 's/^[[:space:]]*#*\[\(.*\)\][[:space:]]*$/\1/')
            
            if [[ "$repo" == "options" ]]; then
                continue
            fi

            if [[ $line =~ ^# ]]; then
                options+="[DISABLED] $repo"$'\n'
            else
                options+="[ENABLED]  $repo"$'\n'
            fi
        fi
    done < /etc/pacman.conf

    options=${options%$'\n'}

    if [ -z "$options" ]; then
        echo "No repositories found in pacman.conf"
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi

    local selected_repos=$(echo -e "$options" | fzf --reverse --multi \
        --style=full:line \
		--preview-border=rounded \
        --header-border=line \
        --header="Select repositories to toggle - Tab for multiple, Enter to confirm, Ctrl+C to cancel" \
        --bind 'ctrl-c:abort' \
        --ansi \
        | sed 's/^\[.*\] *//')

    if [ -n "$selected_repos" ]; then
        echo "$selected_repos" | while read -r repo; do
            toggle_repository "$repo"
        done
        echo
        echo "Repository changes complete."
        read -p "Press any key to continue... " -n 1 -s -r
    fi
}

add_repository() {
    local repo_name
    local server_url

    echo "Add New Repository"
    echo "------------------"
    echo
    read -p "Enter the name of the new repository: " repo_name
    
    if [ -z "$repo_name" ]; then
        echo "Repository name cannot be empty."
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi
    
    if grep -q "^\[$repo_name\]" /etc/pacman.conf || grep -q "^#\[$repo_name\]" /etc/pacman.conf; then
        echo "Repository '$repo_name' already exists in pacman.conf"
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi
    
    read -p "Enter the server URL for the repository: " server_url
    
    if [ -z "$server_url" ]; then
        echo "Server URL cannot be empty."
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi

    echo -e "\n[$repo_name]\nServer = $server_url" | sudo tee -a /etc/pacman.conf > /dev/null
    echo "Repository '$repo_name' added to pacman.conf"
    echo
    read -p "Press any key to continue... " -n 1 -s -r
}

edit_pacman_conf_directly() {
    echo "Opening pacman.conf for editing..."
    echo
    
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
        read -p "Press any key to continue... " -n 1 -s -r
        return 1
    fi
    
    echo "Editing complete."
}

pacman_config_menu() {
    while true; do
        clear_screen

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
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_option=$(printf '%s\n' "${options[@]}" | 
                fzf --reverse \
                    --style=full:line \
					--preview-border=rounded \
                    --border-label=" Pacman Configuration " \
                    --header-border=line \
                    --preview '
                        bold=$(tput bold)
                        normal=$(tput sgr0)
                        cyan=$(tput setaf 6)
                        green=$(tput setaf 2)
                        yellow=$(tput setaf 3)
                        
                        opt=$(echo {} | sed "s/^\[[^]]*\] //")
                        
                        echo -e "${bold}${cyan}Pacman Configuration${normal}"
                        echo
                        
                        current_val=""
                        if grep -q "^$opt" /etc/pacman.conf 2>/dev/null; then
                            current_val=$(grep "^$opt" /etc/pacman.conf | sed "s/.*=//; s/^[[:space:]]*//" | tail -n 1)
                            current_val="${current_val:-Enabled - no value}"
                            echo -e "${bold}${green}Status: ENABLED${normal}"
                        elif grep -q "^#$opt" /etc/pacman.conf 2>/dev/null; then
                            current_val="Disabled - commented out"
                            echo -e "${bold}${yellow}Status: DISABLED${normal}"
                        else
                            current_val="Not set"
                            echo -e "${bold}Status: NOT SET${normal}"
                        fi
                        
                        echo -e "${bold}Option:${normal} $opt"
                        echo -e "${bold}Current Value:${normal} $current_val"
                        echo
                        echo -e "${bold}Description:${normal}"
                        display_preview "$opt" | tail -n +5
                    ' \
                    --preview-window="right:${preview_width}%:wrap" \
                    --preview-label=' Configuration Details ' \
                    --header="Pacman Configuration Menu
Alt+[ increase preview | Alt+] decrease preview | Enter to select | Ctrl+C to return" \
                    --bind 'ctrl-c:abort' \
                    --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                    --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                    --height=$menu_height \
                    --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    return
                fi
            fi
            
            break
        done

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

export -f display_preview
export -f get_option_description
export -f display_pacman_conf
export -f edit_pacman_option
export -f toggle_pacman_option_with_confirmation
export -f toggle_repository
export -f manage_repositories
export -f add_repository
export -f pacman_config_menu
export -f get_recent_updates
export -f get_recent_installs
export -f get_recent_removals
export -f edit_pacman_conf_directly

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
    local preview_file="/var/cache/spm/preview_width"
    local resize_flag="/var/cache/spm/resize_flag"

    exit_script() {
        clear
        echo "Exiting SPM - Simple Package Manager. Goodbye!"
        exit 0
    }

    while true; do
        clear_screen
        preview_width=$(get_preview_width)
        
        echo 0 > "$resize_flag"
        
        while true; do
            preview_width=$(cat "$preview_file")
            
            selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
				--preview-border=rounded \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" SPM Main Menu " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    green=$(tput setaf 2)
                    red=$(tput setaf 1)
                    
                    echo -e "${bold}${cyan}Pacman Log${normal}"
                    echo
                    echo -e "${bold}${green}Recently Updated:${normal}"
                    get_recent_updates 10
                    echo
                    echo -e "${bold}${cyan}Recently Installed:${normal}"
                    get_recent_installs 10
                    echo
                    echo -e "${bold}${red}Recently Removed:${normal}"
                    get_recent_removals 10
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Pacman Log ' \
                --header="SPM Main Menu - Select a function
Alt+[ increase preview | Alt+] decrease preview | Enter to select | Ctrl+C to exit" \
                --bind 'ctrl-c:abort' \
                --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                --height=$menu_height \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$resize_flag"
                    continue
                else
                    exit_script
                fi
            fi
            
            break
        done

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

if [ $sourced -eq 1 ]; then
    export -f update install remove orphan downgrade clear_cache show_help manager dependencies_menu pacman_config_menu
fi

if [ $sourced -eq 0 ]; then
    [ ! -f "$UPDATE_CACHE_FILE" ] && echo "0" > "$UPDATE_CACHE_FILE"
    [ ! -f "$DETAILED_UPDATE_CACHE_FILE" ] && echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"

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
                echo "Use -h or --help for usage information."
                exit 1
                ;;
        esac
    fi
fi