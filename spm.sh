#!/bin/bash

# SPM - Simple Package Manager
# Dependencies: fzf (0.58.0+), yay

CLI_MODE=0

UPDATE_CACHE_FILE="/var/cache/spm/update-cache.txt"
DETAILED_UPDATE_CACHE_FILE="/var/cache/spm/detailed-update-cache.txt"

ensure_spm_var_dir() {
    local dir="/var/cache/spm"
    if [[ ! -d "$dir" ]]; then
        sudo mkdir -p "$dir"
    fi
    if [[ ! -w "$dir" ]]; then
        sudo chmod 777 "$dir"
    fi
    for file in "$UPDATE_CACHE_FILE" "$DETAILED_UPDATE_CACHE_FILE"; do
        if [[ -f "$file" && ! -w "$file" ]]; then
            sudo chmod 666 "$file"
        fi
    done
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
    
    local bold=$(tput bold)
    local cyan=$(tput setaf 6)
    local yellow=$(tput setaf 3)
    local green=$(tput setaf 2)
    local normal=$(tput sgr0)
    
    echo "${bold}${cyan}SPM - Simple Package Manager${normal}"
    echo "${bold}A modern TUI wrapper for pacman/yay with fzf${normal}"
    echo
    echo "${bold}USAGE:${normal}"
    echo "  spm [option] [arguments]"
    echo
    echo "${bold}OPTIONS:${normal}"
    echo "  ${green}-u${normal}, ${green}update${normal}        Update packages (interactive menu)"
    echo "  ${green}-i${normal}, ${green}install${normal}       Install packages"
    echo "  ${green}-r${normal}, ${green}remove${normal}        Remove packages"
    echo "  ${green}-o${normal}, ${green}orphan${normal}        Clean orphaned packages (interactive menu)"
    echo "  ${green}-d${normal}, ${green}downgrade${normal}     Downgrade packages"
    echo "  ${green}-c${normal}, ${green}cache${normal}         Clear package cache (interactive menu)"
    echo "  ${green}-h${normal}, ${green}--help${normal}        Display this help message"
    echo
    echo "${bold}EXAMPLES:${normal}"
    echo "  ${yellow}spm${normal}                   Launch interactive menu"
    echo "  ${yellow}spm -i firefox${normal}        Install Firefox"
    echo "  ${yellow}spm -r firefox${normal}        Remove Firefox"
    echo "  ${yellow}spm -u${normal}                Update packages menu"
    echo
    echo "${bold}SYSTEMD TIMER:${normal}"
    echo "  Enable automatic update checking and cache syncing:"
    echo "  ${yellow}systemctl enable --now spm_updates.timer${normal}"
    echo
    echo "  Check timer status:"
    echo "  ${yellow}systemctl status spm_updates.timer${normal}"
    echo
    echo "${bold}CONFIGURATION:${normal}"
    echo "  Cache location:     /var/cache/spm/"
    echo "  Pacman config:      /etc/pacman.conf"
    echo
    echo "For more information, visit:"
    echo "${cyan}https://github.com/adelmonte/Simple_Package_Manager${normal}"
    echo
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
    while true; do
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
        
        local menu_label
        local header_text
        if [ $CLI_MODE -eq 1 ]; then
            menu_label="← Exit"
            header_text="Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            header_text="Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi
        
        local selected_option=$(printf '%s\n' \
            "All [Auto]" \
            "All [Review]" \
            "System [Review]" \
            "Flatpak [Review]" \
            "AUR-devel [Review]" \
            "$menu_label" | 
            fzf --reverse \
                --layout=reverse-list \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
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
                        "All [Auto]"*)           echo "yes | yay && flatpak update --assumeyes" ;;
                        "All [Review]"*)         echo "yay && flatpak update" ;;
                        "System [Review]"*)      echo "yay -Syu" ;;
                        "Flatpak [Review]"*)     echo "flatpak update" ;;
                        "AUR-devel"*)            echo "yay -Sua --devel" ;;
                        *)                       echo "No command to execute" ;;
                    esac
                    echo
                    echo -e "${bold}Upgradable Packages:${normal}"
                    echo
                    cat "'$DETAILED_UPDATE_CACHE_FILE'" 2>/dev/null || echo "No update information available."
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Update Information ' \
                --header="$header_text" \
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
                if [ $CLI_MODE -eq 1 ]; then
                    clear
                    echo "Exiting SPM - Simple Package Manager. Goodbye!"
                fi
                return
            fi
        fi

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [ $CLI_MODE -eq 1 ]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

        trap 'echo; echo "Update cancelled. Returning to menu..."; sleep 1; continue' INT

        case "$selected_option" in
            "All [Auto]"*)
                echo "Performing quick update..."
                yes | yay
                flatpak update --assumeyes
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f /var/cache/spm/package-list-cache.txt
                ;;
            "All [Review]"*)
                echo "Performing full update..."
                yay
                flatpak update
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f /var/cache/spm/package-list-cache.txt
                ;;
            "System [Review]"*)
                echo "Updating yay packages..."
                yay -Syu
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f /var/cache/spm/package-list-cache.txt
                ;;
            "Flatpak [Review]"*)
                echo "Updating Flatpak apps..."
                flatpak update
                ;;
            "AUR-devel"*)
                echo "Checking AUR development packages for updates..."
                yay -Sua --devel
                ;;
        esac
        
        trap - INT
        
        echo
        if [ $CLI_MODE -eq 1 ]; then
            read -p "Press any key to return to update menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            continue
        else
            read -p "Press any key to return to main menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            return
        fi
    done
}

install() {
    while true; do
        clear_screen
        
        local search_query="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"
        local cache_file="/var/cache/spm/package-list-cache.txt"
        local installed_temp="/tmp/spm_installed_$BASHPID.tmp"

        echo 0 > "$resize_flag"

        # Check if cache exists and if timer is enabled
        local regenerate_cache=false
        
        if [[ ! -f "$cache_file" ]]; then
            regenerate_cache=true
        elif ! systemctl is-enabled spm_updates.timer &>/dev/null; then
            # Timer is not enabled, regenerate cache every time
            regenerate_cache=true
        fi

        if [ "$regenerate_cache" = true ]; then
            echo "Generating package cache... This may take a moment."
            local repo_order=$(grep '^\[.*\]' /etc/pacman.conf | grep -v '^\[options\]' | sed 's/[][]//g' | tr '\n' ' ')
            pacman -Qq 2>/dev/null > "$installed_temp"
            
            if [[ ! -f "$installed_temp" ]]; then
                echo "Error: Could not create temp file at $installed_temp"
                sleep 3
                return
            fi
            
            timeout 30 yay -Sl 2>&1 | grep -v "^Get " | awk -v repo_order="$repo_order" -v installed_file="$installed_temp" '
            BEGIN {
                split(repo_order, repos)
                for (i in repos) {
                    repo_priority[repos[i]] = i
                }
                while ((getline pkg < installed_file) > 0) {
                    is_installed[pkg] = 1
                }
                close(installed_file)
            }
            {
                repo = $1
                package = $2
                version = $3
                if (version == "" || version == "unknown" || version == "unknown-version") {
                    version = "unknown"
                }
                priority = (repo in repo_priority) ? repo_priority[repo] : (repo == "aur" ? 998 : 999)
                installed_priority = (package in is_installed) ? 0 : 1
                status = (package in is_installed) ? "[INSTALLED]" : ""
                
                if (repo == "aur") {
                    printf "%01d %03d %s|%s|%s\n", installed_priority, priority, package, repo, status
                } else {
                    printf "%01d %03d %s %s|%s|%s\n", installed_priority, priority, package, version, repo, status
                }
            }' | sort -n | cut -d' ' -f3- | column -t -s'|' > "$cache_file"
            
            local exit_code=$?
            rm -f "$installed_temp"
            
            if [[ $exit_code -eq 124 ]]; then
                echo "Warning: Package list generation timed out (AUR may be slow)."
                echo "Retrying without timeout..."
                sleep 2
                rm -f "$cache_file"
                continue
            fi
            
            if [[ ! -s "$cache_file" ]]; then
                echo "Error: Failed to generate package cache."
                echo "This may be due to network issues with AUR."
                echo ""
                read -p "Press any key to retry or Ctrl+C to exit... " -n 1 -s -r
                echo
                rm -f "$cache_file"
                continue
            fi
            
            # Show a message if timer is not enabled
            if ! systemctl is-enabled spm_updates.timer &>/dev/null; then
                echo
                echo "Note: Enable spm_updates.timer to keep the cache updated automatically:"
                echo "  systemctl enable --now spm_updates.timer"
                echo
                sleep 2
            fi
        fi

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_packages=$(cat "$cache_file" | fzf --multi --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --scrollbar='█' \
                --preview-border=rounded \
                --header-border=line \
                --border-label=" Install Packages " \
                --preview "
                    bold=\$(tput bold)
                    normal=\$(tput sgr0)
                    cyan=\$(tput setaf 6)
                    green=\$(tput setaf 2)
                    yellow=\$(tput setaf 3)
                    
                    pkg_name=\$(echo {} | awk '{print \$1}')
                    
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
                --header="Select packages to install - Tab to multi-select | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
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
                    if [ $CLI_MODE -eq 1 ]; then
                        echo
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi
            
            break
        done

        local bold=$(tput bold)
        local green=$(tput setaf 2)
        local cyan=$(tput setaf 6)
        local normal=$(tput sgr0)
        
        echo "${bold}${cyan}The following packages will be installed:${normal}"
        echo "$selected_packages" | sed "s/^/  ${green}→${normal} /"
        echo
        
        if [ $CLI_MODE -eq 1 ]; then
            trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
            read -p "${bold}Do you want to proceed? [Y/n]${normal} " confirm
            trap - INT
        else
            (
                trap 'exit 130' INT
                read -p "${bold}Do you want to proceed? [Y/n]${normal} " confirm
                echo "$confirm" > /tmp/spm_install_confirm_$$
            )
            if [ $? -eq 130 ]; then
                echo
                echo "Operation cancelled. Returning to package selection..."
                sleep 1
                continue
            fi
            confirm=$(cat /tmp/spm_install_confirm_$$ 2>/dev/null)
            rm -f /tmp/spm_install_confirm_$$
        fi
        
        case $confirm in
            [Nn]* ) 
                echo "Operation cancelled."
                sleep 1
                continue
                ;;
            * ) 
                yay -S $selected_packages
                rm -f "$cache_file"
                echo
                if [ $CLI_MODE -eq 1 ]; then
                    read -p "Press any key to return to install menu or Ctrl+C to exit... " -n 1 -s -r
                    echo
                    continue
                else
                    read -p "Press any key to return to main menu or Ctrl+C to exit... " -n 1 -s -r
                    echo
                    return
                fi
                ;;
        esac
    done
}

remove() {
    while true; do
        clear_screen
        
        local bold=$(tput bold)
        local normal=$(tput sgr0)
        
        echo "${bold}Remove Packages${normal}"
        echo "---------------"
        
        local search_query="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        local selected_packages=$(pacman -Qq | fzf --multi --reverse \
            --style=full:line \
            --no-highlight-line \
            --cycle \
            --scrollbar='█' \
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
            --header="Select packages to remove - Tab to multi-select | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
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
                if [ $CLI_MODE -eq 1 ]; then
                    echo
                    echo "Exiting SPM - Simple Package Manager. Goodbye!"
                fi
                return
            fi
        fi

        local bold=$(tput bold)
        local cyan=$(tput setaf 6)
        local yellow=$(tput setaf 3)
        local red=$(tput setaf 1)
        local normal=$(tput sgr0)
        
        echo "The following packages will be removed:"
        echo "$selected_packages" | sed 's/^/  → /' | while read line; do
            echo -e "${red}${line}${normal}"
        done
        echo
        
        echo "${bold}Package Removal Options:${normal}"
        echo "------------------------"
        echo
        
        local pacman_args=""
        
        echo "  ${bold}1)${normal} Full removal (package, deps, configs, and reverse deps) ${yellow}-Rnsc${normal}"
        echo "  ${bold}2)${normal} Standard removal (package, deps, and configs) ${yellow}-Rns${normal}"
        echo "  ${bold}3)${normal} Remove package and configs only ${yellow}-Rn${normal}"
        echo "  ${bold}4)${normal} Remove package and dependencies ${yellow}-Rs${normal}"
        echo "  ${bold}5)${normal} Remove package only ${yellow}-R${normal}"
        echo "  ${bold}6)${normal} Force removal ignoring dependencies ${yellow}-Rdd${normal} ${red}(dangerous)${normal}"
        echo "  ${bold}7)${normal} Force removal with configs ${yellow}-Rddn${normal} ${red}(dangerous)${normal}"
        echo
        
        if [ $CLI_MODE -eq 1 ]; then
            trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
            read -p "Enter option 1-7 [1] (Ctrl+C to cancel): " remove_option
            trap - INT
        else
            (
                trap 'exit 130' INT
                read -p "Enter option 1-7 [1] (Ctrl+C to cancel): " remove_option
                echo "$remove_option" > /tmp/spm_remove_option_$$
            )
            if [ $? -eq 130 ]; then
                echo
                echo "Operation cancelled. Returning to package selection..."
                sleep 1
                continue
            fi
            remove_option=$(cat /tmp/spm_remove_option_$$ 2>/dev/null)
            rm -f /tmp/spm_remove_option_$$
        fi

        case $remove_option in
            1|"") pacman_args="-Rnsc";;
            2) pacman_args="-Rns";;
            3) pacman_args="-Rn";;
            4) pacman_args="-Rs";;
            5) pacman_args="-R";;
            6) pacman_args="-Rdd";;
            7) pacman_args="-Rddn";;
            *) 
                echo "Invalid option."
                sleep 1
                continue
                ;;
        esac

        read -p "Proceed with removal using $pacman_args? [Y/n] " confirm
        case $confirm in
            [Nn]* ) 
                echo "Operation cancelled."
                sleep 1
                continue
                ;;
            * ) 
                yay $pacman_args $selected_packages
                rm -f /var/cache/spm/package-list-cache.txt
                echo
                if [ $CLI_MODE -eq 1 ]; then
                    read -p "Press any key to return to remove menu or Ctrl+C to exit... " -n 1 -s -r
                    echo
                    continue
                else
                    read -p "Press any key to return to main menu or Ctrl+C to exit... " -n 1 -s -r
                    echo
                    return
                fi
                ;;
        esac
    done
}

explore_dependencies() {
    while true; do
        
        local bold=$(tput bold)
        local cyan=$(tput setaf 6)
        local normal=$(tput sgr0)

        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            
            local package_list=$(pacman -Qd | awk '{print $1}')
            local selected_package=$(echo "$package_list" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --scrollbar='█' \
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
                    echo -e "${bold}${green}Required By:${normal}"
                    echo "Packages that depend on this:"
                    req_by=$(pacman -Qi {1} | grep "Required By" | cut -d":" -f2-)
                    if [[ "$req_by" == *"None"* ]]; then
                        echo "  ${green}None - can be safely removed${normal}"
                    else
                        echo "$req_by" | tr " " "\n" | sed "s/^/  /"
                    fi
                    echo
                    echo -e "${bold}${yellow}Dependencies:${normal}"
                    echo "This package depends on:"
                    pacman -Qi {1} | grep "Depends On" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Dependency Information ' \
                --header="Select a dependency package to explore | Enter to view details | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
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
            echo "${bold}${cyan}Package: $selected_package${normal}"
            echo "Description: $(pacman -Qi $selected_package | grep "Description" | cut -d":" -f2-)"
            echo
            echo "${bold}${green}Required By:${normal}"
            echo "Packages that depend on this:"
            pacman -Qi $selected_package | grep "Required By" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            echo "${bold}${yellow}Dependencies:${normal}"
            echo "This package depends on:"
            pacman -Qi $selected_package | grep "Depends On" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            read -p "Press any key to continue exploring or Ctrl+C to return. " -n 1 -s -r
            break
        done
    done
}

find_high_impact_removals() {
    local temp_file=$(mktemp)
    
    local bold=$(tput bold)
    local cyan=$(tput setaf 6)
    local green=$(tput setaf 2)
    local yellow=$(tput setaf 3)
    local normal=$(tput sgr0)
    
    echo "${bold}${cyan}Analyzing High-Impact Removals...${normal}"
    echo "Finding packages that would remove the most dependencies."
    echo
    
    local packages=($(pacman -Qq))
    echo "Analyzing ${#packages[@]} installed packages..."
	echo
    echo "Press Ctrl+C to cancel."
    echo
    
    local explicit_list=$(pacman -Qe | cut -d' ' -f1 | tr '\n' ' ')
    
    trap 'echo; echo "Analysis cancelled."; rm -f "$temp_file"; return' INT
    
    for pkg in "${packages[@]}"; do
        (
            removal_list=$(pacman -Rsp "$pkg" 2>/dev/null)
            
            if [ -z "$removal_list" ]; then
                exit 0
            fi
            
            conflict=false
            for removed_pkg in $removal_list; do
                if [[ "$removed_pkg" != "$pkg" ]] && [[ " $explicit_list " =~ " $removed_pkg " ]]; then
                    conflict=true
                    break
                fi
            done
            
            if [ "$conflict" = false ]; then
                removed_count=$(echo "$removal_list" | wc -l)
                printf "%d %s\n" "$removed_count" "$pkg"
            fi
        ) &
        
        if (( $(jobs -r | wc -l) >= 12 )); then
            wait -n
        fi
    done >> "$temp_file"
    
    wait
    
    trap - INT
    
    sort -nr "$temp_file" > "${temp_file}.sorted"
    mv "${temp_file}.sorted" "$temp_file"
    
    if [ ! -s "$temp_file" ]; then
        echo "${yellow}No high-impact removal candidates found.${normal}"
        rm "$temp_file"
        read -p "Press any key to return... " -n 1 -s -r
        return
    fi

    local preview_width=$(get_preview_width)
    local preview_file="/var/cache/spm/preview_width"
    local resize_flag="/var/cache/spm/resize_flag"

    echo 0 > "$resize_flag"

    while true; do
        preview_width=$(cat "$preview_file")
        
        local selected_line=$(cat "$temp_file" | fzf --reverse \
            --style=full:line \
            --no-highlight-line \
            --cycle \
            --scrollbar='█' \
            --preview-border=rounded \
            --header-border=line \
            --border-label=" High-Impact Removals " \
            --preview '
                bold=$(tput bold)
                normal=$(tput sgr0)
                cyan=$(tput setaf 6)
                yellow=$(tput setaf 3)
                green=$(tput setaf 2)
                
                pkg=$(echo {} | awk "{print \$2}")
                count=$(echo {} | awk "{print \$1}")
                
                echo -e "${bold}${cyan}$pkg${normal}"
                echo
                pacman -Qi "$pkg" 2>/dev/null | grep "Description" | cut -d":" -f2-
                echo
                echo -e "${bold}${yellow}Would remove $count package(s)${normal}"
                echo
                echo -e "${bold}${green}Install Reason:${normal}"
                pacman -Qi "$pkg" 2>/dev/null | grep "Install Reason" | cut -d":" -f2-
                echo
                echo -e "${bold}Dependencies to be removed:${normal}"
                pacman -Rsp "$pkg" 2>/dev/null | sed "s/^/  /" | head -30
                removal_count=$(pacman -Rsp "$pkg" 2>/dev/null | wc -l)
                if [ "$removal_count" -gt 30 ]; then
                    echo "  ... and $((removal_count - 30)) more"
                fi
                echo
                echo -e "${bold}Install Information:${normal}"
                pacman -Qi "$pkg" 2>/dev/null | grep -E "Install Date|Installed Size" | sed "s/^/  /"
            ' \
            --preview-window="right:${preview_width}%:wrap" \
            --preview-label=' Removal Impact ' \
            --header="High-impact removal candidates - sorted by dependency count
Alt+[ increase preview | Alt+] decrease preview | Enter to view | Ctrl+C to return" \
            --bind 'ctrl-c:abort' \
            --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
            --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
            --ansi)
        
        if [[ -z "$selected_line" ]]; then
            if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                echo 0 > "$resize_flag"
                continue
            else
                rm "$temp_file"
                return
            fi
        fi

        local selected_package=$(echo "$selected_line" | awk '{print $2}')
        local removed_count=$(echo "$selected_line" | awk '{print $1}')

        clear_screen
        echo "${bold}${cyan}Package: $selected_package${normal}"
        echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2-)"
        echo
        echo "${bold}${green}Install Reason:${normal}"
        pacman -Qi "$selected_package" | grep "Install Reason" | cut -d":" -f2-
        echo
        echo "${bold}${yellow}Would remove $removed_count package(s)${normal}"
        echo
        echo "${bold}Dependencies to be removed:${normal}"
        pacman -Rsp "$selected_package" 2>/dev/null | sed 's/^/  /'
        echo
        echo "${bold}Install Information:${normal}"
        pacman -Qi "$selected_package" | grep -E "Install Reason|Install Date|Installed Size" | sed 's/^/  /'
        echo
        read -p "Press any key to return to package list... " -n 1 -s -r
    done
    
    rm "$temp_file"
}

browse_explicit_packages() {
    while true; do
        
        local bold=$(tput bold)
        local cyan=$(tput setaf 6)
        local normal=$(tput sgr0)

        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        while true; do
            preview_width=$(cat "$preview_file")
            
            local package_list=$(pacman -Qe | awk '{print $1}')
            local selected_package=$(echo "$package_list" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --scrollbar='█' \
                --preview-border=rounded \
                --header-border=line \
                --border-label=" Explicitly Installed Packages " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    yellow=$(tput setaf 3)
                    red=$(tput setaf 1)
                    
                    pkg={1}
                    
                    echo -e "${bold}${cyan}$pkg${normal}"
                    echo
                    pacman -Qi "$pkg" 2>/dev/null | grep "Description" | cut -d":" -f2- | sed "s/^//"
                    echo
                    echo -e "${bold}${yellow}Removal Impact:${normal}"
                    
                    removal_list=$(pacman -Rsp "$pkg" 2>/dev/null)
                    removed_count=$(echo "$removal_list" | wc -l)
                    
                    explicit_list=$(pacman -Qe | cut -d" " -f1 | tr "\n" " ")
                    
                    conflict=false
                    for removed in $removal_list; do
                        if [[ "$removed" != "$pkg" ]] && [[ " $explicit_list " =~ " $removed " ]]; then
                            conflict=true
                            break
                        fi
                    done
                    
                    if [ "$conflict" = true ]; then
                        echo -e "${red}Would remove other explicit packages${normal}"
                    else
                        echo -e "Would remove ${yellow}$removed_count${normal} total packages"
                    fi
                    echo
                    echo -e "${bold}Dependencies to be removed:${normal}"
                    echo "$removal_list" | head -30 | sed "s/^/  /"
                    if [ "$removed_count" -gt 30 ]; then
                        echo "  ... and $((removed_count - 30)) more"
                    fi
                    echo
                    echo -e "${bold}Installed:${normal}"
                    pacman -Qi "$pkg" 2>/dev/null | grep "Install Date" | cut -d":" -f2- | sed "s/^/  /"
                    echo -e "${bold}Size:${normal}"
                    pacman -Qi "$pkg" 2>/dev/null | grep "Installed Size" | cut -d":" -f2- | sed "s/^/  /"
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Removal Impact ' \
                --header="Browse explicitly installed packages | Enter to view details | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
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
            local bold=$(tput bold)
            local cyan=$(tput setaf 6)
            local yellow=$(tput setaf 3)
            local red=$(tput setaf 1)
            local normal=$(tput sgr0)
            
            echo "${bold}${cyan}Package: $selected_package${normal}"
            echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2-)"
            echo
            echo "${bold}${yellow}Removal Impact:${normal}"
            
            removal_list=$(pacman -Rsp "$selected_package" 2>/dev/null)
            removed_count=$(echo "$removal_list" | wc -l)
            
            explicit_list=$(pacman -Qe | cut -d' ' -f1 | tr '\n' ' ')
            
            conflict=false
            for removed in $removal_list; do
                if [[ "$removed" != "$selected_package" ]] && [[ " $explicit_list " =~ " $removed " ]]; then
                    conflict=true
                    break
                fi
            done
            
            if [ "$conflict" = true ]; then
                echo -e "${red}Would remove other explicitly installed packages${normal}"
            else
                echo -e "Would remove ${yellow}$removed_count${normal} total packages"
            fi
            
            echo
            echo "${bold}Dependencies to be removed:${normal}"
            echo "$removal_list" | sed 's/^/  /'
            echo
            echo "${bold}Install Information:${normal}"
            pacman -Qi "$selected_package" | grep -E "Install Reason|Install Date|Installed Size" | sed 's/^/  /'
            echo
            read -p "Press any key to continue or Ctrl+C to return. " -n 1 -s -r
            break
        done
    done
}

dependencies_menu() {
    while true; do
        clear_screen

        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        local options=(
            "Explore Dependencies"
            "High-Impact Removals"
            "Browse Explicit Packages"
            "← Menu"
        )
        local header_height=8
        local menu_height=$(($(tput lines) - $header_height - 1))

        while true; do
            preview_width=$(cat "$preview_file")

            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --layout=reverse-list \
                --cycle \
                --no-input \
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
                            echo -e "${bold}Explore Dependencies${normal}"
                            echo
                            echo "Browse dependency packages and examine relationships."
                            echo
                            echo -e "${bold}What this does:${normal}"
                            echo "• Lists packages installed as dependencies"
                            echo "• Shows which packages require each dependency"
                            echo "• Displays dependencies of each package"
                            echo
                            echo -e "${bold}Use case:${normal}"
                            echo "Understanding package dependency relationships."
                            ;;
                        "High-Impact Removals")
                            echo -e "${bold}High-Impact Removals${normal}"
                            echo
                            echo "Find all packages that would remove the most"
                            echo "dependencies without affecting explicitly installed packages."
                            echo
                            echo -e "${bold}What this does:${normal}"
                            echo "• Analyzes ALL installed packages (explicit + deps)"
                            echo "• Counts dependencies that would be removed"
                            echo "• Filters out removals affecting explicit packages"
                            echo "• Searchable and sortable by impact"
                            echo
                            echo -e "${bold}Use case:${normal}"
                            echo "Finding orphaned or safe-to-remove packages for cleanup."
                            ;;
                        "Browse Explicit Packages")
                            echo -e "${bold}Browse Explicit Packages${normal}"
                            echo
                            echo "Browse all explicitly installed packages and examine"
                            echo "what would be removed with each one."
                            echo
                            echo -e "${bold}What this does:${normal}"
                            echo "• Lists all explicitly installed packages"
                            echo "• Shows removal impact for each package"
                            echo "• Indicates if removal would affect other explicit packages"
                            echo "• Displays full removal list"
                            echo
                            echo -e "${bold}Use case:${normal}"
                            echo "Exploring removal options for explicit packages."
                            ;;
                        *)
                            echo "Return to the main menu"
                            ;;
                    esac
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Function Description ' \
                --header="Dependencies Menu - Select a function
Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
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
            "Explore Dependencies")
                explore_dependencies
                ;;
            "High-Impact Removals")
                find_high_impact_removals
                ;;
            "Browse Explicit Packages")
                browse_explicit_packages
                ;;
            "← Menu")
                return
                ;;
        esac
    done
}

orphan() {
    while true; do
        clear_screen
        
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        local menu_label
        local header_text
        if [ $CLI_MODE -eq 1 ]; then
            menu_label="← Exit"
            header_text="Select an option to clean packages - Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            header_text="Select an option to clean packages - Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local options=(
            "All Orphans [Auto]"
            "Orphaned Only [Review]"
            "Unneeded Only [Review]"
            "Both Types [Review]"
            "$menu_label"
        )

        local header_height=7
        local menu_height=$(($(tput lines) - $header_height - 1))

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --layout=reverse-list \
                --cycle \
                --no-input \
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
                        "All Orphans [Auto]"*)
                            echo "sudo pacman -Rns \$(pacman -Qdtq) --noconfirm"
                            echo "sudo pacman -Rsu \$(pacman -Qqd) --noconfirm"
                            ;;
                        "Orphaned Only"*)
                            echo "sudo pacman -Rns \$(pacman -Qdtq)"
                            ;;
                        "Unneeded Only"*)
                            echo "sudo pacman -Rsu \$(pacman -Qqd)"
                            ;;
                        "Both Types"*)
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
                    if [ -n "$orphans" ]; then
                        orphan_count=$(echo "$orphans" | wc -l)
                        echo "Count: $orphan_count"
                        echo
                        echo "$orphans" | head -20
                        if [ $orphan_count -gt 20 ]; then
                            echo "... and $((orphan_count - 20)) more"
                        fi
                    else
                        echo "Count: 0"
                        echo
                        echo "None found"
                    fi
                    echo
                    echo -e "${bold}${red}Unneeded Packages:${normal}"
                    echo "Dependencies not required by explicitly installed packages"
                    unneeded=$(pacman -Qqd 2>/dev/null | xargs pacman -Rsu --print 2>/dev/null | grep "^  " | awk "{print \$1}")
                    if [ -n "$unneeded" ]; then
                        unneeded_count=$(echo "$unneeded" | wc -l)
                        echo "Count: $unneeded_count"
                        echo
                        echo "$unneeded" | head -20
                        if [ $unneeded_count -gt 20 ]; then
                            echo "... and $((unneeded_count - 20)) more"
                        fi
                    else
                        echo "Count: 0"
                        echo
                        echo "None found"
                    fi
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Orphaned and Unneeded Packages ' \
                --header="$header_text" \
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
                    if [ $CLI_MODE -eq 1 ]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi
            
            break
        done

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [ $CLI_MODE -eq 1 ]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

        local operation_cancelled=false
        
        case "$selected_option" in
            "All Orphans [Auto]"*)
                echo "Performing quick removal..."
                sudo pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null
                sudo pacman -Rsu $(pacman -Qqd) --noconfirm 2>/dev/null
                echo "Removal complete."
                ;;
            "Orphaned Only"*)
                local orphans=$(pacman -Qdtq 2>/dev/null)
                if [ -n "$orphans" ]; then
                    echo "The following orphaned packages will be removed:"
                    echo "$orphans" | sed 's/^/  → /'
                    echo
                    
                    local confirm
                    if [ $CLI_MODE -eq 1 ]; then
                        trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                        read -p "Do you want to proceed? [Y/n] " confirm
                        trap - INT
                    else
                        (
                            trap 'exit 130' INT
                            read -p "Do you want to proceed? [Y/n] " confirm
                            echo "$confirm" > /tmp/spm_orphan_confirm_$$
                        )
                        if [ $? -eq 130 ]; then
                            echo
                            echo "Operation cancelled. Returning to menu..."
                            sleep 1
                            operation_cancelled=true
                        else
                            confirm=$(cat /tmp/spm_orphan_confirm_$$ 2>/dev/null)
                            rm -f /tmp/spm_orphan_confirm_$$
                        fi
                    fi
                    
                    if ! $operation_cancelled; then
                        if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                            sudo pacman -Rns $orphans
                        else
                            echo "Operation cancelled."
                            sleep 1
                            continue
                        fi
                    fi
                else
                    echo "No orphaned packages found."
                    sleep 1
                    continue
                fi
                ;;
            "Unneeded Only"*)
                local unneeded=$(pacman -Qqd 2>/dev/null | xargs pacman -Rsu --print 2>/dev/null | grep "^  " | awk '{print $1}')
                if [ -n "$unneeded" ]; then
                    echo "The following unneeded packages will be removed:"
                    echo "$unneeded" | sed 's/^/  → /'
                    echo
                    
                    local confirm
                    if [ $CLI_MODE -eq 1 ]; then
                        trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                        read -p "Do you want to proceed? [Y/n] " confirm
                        trap - INT
                    else
                        (
                            trap 'exit 130' INT
                            read -p "Do you want to proceed? [Y/n] " confirm
                            echo "$confirm" > /tmp/spm_orphan_confirm_$$
                        )
                        if [ $? -eq 130 ]; then
                            echo
                            echo "Operation cancelled. Returning to menu..."
                            sleep 1
                            operation_cancelled=true
                        else
                            confirm=$(cat /tmp/spm_orphan_confirm_$$ 2>/dev/null)
                            rm -f /tmp/spm_orphan_confirm_$$
                        fi
                    fi
                    
                    if ! $operation_cancelled; then
                        if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                            sudo pacman -Rsu $(pacman -Qqd) 2>/dev/null
                        else
                            echo "Operation cancelled."
                            sleep 1
                            continue
                        fi
                    fi
                else
                    echo "No unneeded packages found."
                    sleep 1
                    continue
                fi
                ;;
            "Both Types"*)
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
                    
                    local confirm
                    if [ $CLI_MODE -eq 1 ]; then
                        trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                        read -p "Do you want to proceed? [Y/n] " confirm
                        trap - INT
                    else
                        (
                            trap 'exit 130' INT
                            read -p "Do you want to proceed? [Y/n] " confirm
                            echo "$confirm" > /tmp/spm_orphan_confirm_$$
                        )
                        if [ $? -eq 130 ]; then
                            echo
                            echo "Operation cancelled. Returning to menu..."
                            sleep 1
                            operation_cancelled=true
                        else
                            confirm=$(cat /tmp/spm_orphan_confirm_$$ 2>/dev/null)
                            rm -f /tmp/spm_orphan_confirm_$$
                        fi
                    fi
                    
                    if ! $operation_cancelled; then
                        if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                            [ -n "$orphans" ] && sudo pacman -Rns $orphans
                            [ -n "$unneeded" ] && sudo pacman -Rsu $(pacman -Qqd) 2>/dev/null
                        else
                            echo "Operation cancelled."
                            sleep 1
                            continue
                        fi
                    fi
                else
                    echo "No orphaned or unneeded packages found."
                    sleep 1
                    continue
                fi
                ;;
        esac
        
        if $operation_cancelled; then
            continue
        fi
        
        rm -f /var/cache/spm/package-list-cache.txt
        
        echo
        if [ $CLI_MODE -eq 1 ]; then
            read -p "Press any key to return to orphan menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            continue
        else
            read -p "Press any key to return to main menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            return
        fi
    done
}

downgrade() {
    while true; do
        clear_screen
        
        local packages="$1"
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"
        echo 0 > "$resize_flag"
        
        local header_text
        if [ $CLI_MODE -eq 1 ]; then
            header_text="Select packages to downgrade - Tab to multi-select | Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            header_text="Select packages to downgrade - Tab to multi-select | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi
        
        if [ -z "$packages" ]; then
            while true; do
                preview_width=$(cat "$preview_file")
                
                packages=$(pacman -Qq | fzf --reverse --multi \
                    --style=full:line \
                    --no-highlight-line \
                    --cycle \
                    --scrollbar='█' \
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
                    --header="$header_text" \
                    --bind 'ctrl-c:abort' \
                    --bind "alt-[:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                    --bind "alt-]:execute-silent(new_width=\$(cat $preview_file); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $preview_file; echo 1 > $resize_flag)+abort" \
                    --ansi)
                
                if [[ -z "$packages" ]]; then
                    if [[ $(cat "$resize_flag" 2>/dev/null || echo "0") -eq 1 ]]; then
                        echo 0 > "$resize_flag"
                        continue
                    else
                        if [ $CLI_MODE -eq 1 ]; then
                            clear
                            echo "Exiting SPM - Simple Package Manager. Goodbye!"
                        fi
                        return
                    fi
                else
                    break
                fi
            done
        fi
        
        for package in $packages; do
            clear_screen
            
            local bold=$(tput bold)
            local yellow=$(tput setaf 3)
            local cyan=$(tput setaf 6)
            local green=$(tput setaf 2)
            local normal=$(tput sgr0)
            
            echo "${bold}${yellow}⬇ Downgrading: $package${normal}"
            echo
            
            if ! pacman -Qi "$package" > /dev/null 2>&1; then
                echo "Package $package is not installed. Skipping..."
                sleep 2
                continue
            fi
            
            local current_version=$(pacman -Q "$package" 2>/dev/null | awk '{print $2}')
            echo "${bold}Current version:${normal} ${green}$current_version${normal}"
            echo
            echo "Searching for available versions..."
            
            local arch=$(uname -m)
            local candidates=()
            local cache_versions=()
            local ala_versions=()
            
            cache_versions=($(find /var/cache/pacman/pkg/ -maxdepth 1 -name "${package}-[0-9]*.pkg.tar.*" ! -name "*.sig" 2>/dev/null | sort -V -r))
            
            if [ ${#cache_versions[@]} -gt 0 ]; then
                echo "Found ${#cache_versions[@]} cached version(s)"
                candidates+=("${cache_versions[@]}")
            fi
            
            echo "Searching Arch Linux Archive..."
            local ala_list=$(curl -s "https://archive.archlinux.org/packages/${package:0:1}/$package/" 2>/dev/null | \
                grep -oP "${package}-[0-9][^\"]*\.pkg\.tar\.[^\"]*(?=\")" | \
                grep -v "\.sig$" | \
                grep -E "(${arch}|any)\.pkg\.tar\." | \
                sort -V -r)
            
            if [ -n "$ala_list" ]; then
                while IFS= read -r ver; do
                    ala_versions+=("ALA:$ver")
                done <<< "$ala_list"
                echo "Found ${#ala_versions[@]} version(s) in Arch Linux Archive"
                candidates+=("${ala_versions[@]}")
            fi
            
            if [ ${#candidates[@]} -eq 0 ]; then
                echo
                echo "No versions found for $package."
                echo "This could mean:"
                echo "  • The package is from AUR (not in official repos)"
                echo "  • No cached versions exist locally"
                echo "  • Network connectivity issues"
                echo
                read -p "Press any key to continue..." -n 1 -s -r
                continue
            fi
            
            echo
            echo "Total available versions: ${#candidates[@]}"
            echo
            
            while true; do
                preview_width=$(cat "$preview_file")
                
                local selected_version=$(printf '%s\n' "${candidates[@]}" | fzf --reverse \
                    --style=full:line \
                    --no-highlight-line \
                    --preview-border=rounded \
                    --cycle \
                    --header-border=line \
                    --border-label=" Select Version for $package " \
                    --preview "
                        bold=\$(tput bold)
                        normal=\$(tput sgr0)
                        cyan=\$(tput setaf 6)
                        yellow=\$(tput setaf 3)
                        green=\$(tput setaf 2)
                        
                        echo -e \"\${bold}\${yellow}⬇ Downgrading: $package\${normal}\"
                        echo
                        echo -e \"\${bold}Current version:\${normal} \${green}$current_version\${normal}\"
                        echo
                        echo -e \"\${bold}\${cyan}Selected Version\${normal}\"
                        
                        version={}
                        if [[ \$version == ALA:* ]]; then
                            version=\${version#ALA:}
                            echo -e \"\${bold}Source:\${normal} Arch Linux Archive\"
                            echo -e \"\${bold}File:\${normal} \$version\"
                            echo
                            echo \"This version will be downloaded before installation.\"
                        else
                            echo -e \"\${bold}Source:\${normal} Local cache\"
                            echo -e \"\${bold}Location:\${normal} \$version\"
                            echo
                            echo -e \"\${bold}Package Details:\${normal}\"
                            pacman -Qip \"\$version\" 2>/dev/null || echo 'Details not available'
                        fi
                    " \
                    --preview-window="right:$preview_width%:wrap" \
                    --preview-label=" Version for $package " \
                    --header="Select a version to downgrade $package - Enter to confirm | Ctrl+C to skip
Alt+[ increase preview | Alt+] decrease preview" \
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
                        sleep 1
                        break
                    fi
                else
                    break
                fi
            done
            
            if [ -n "$selected_version" ]; then
                echo
                
                if [[ "$selected_version" == ALA:* ]]; then
                    local filename="${selected_version#ALA:}"
                    local download_path="/tmp/$filename"
                    
                    echo "Downloading $filename from Arch Linux Archive..."
                    if wget -q --show-progress "https://archive.archlinux.org/packages/${package:0:1}/$package/$filename" -O "$download_path" 2>/dev/null; then
                        if [ -f "$download_path" ]; then
                            echo
                            sudo pacman -U "$download_path"
                            local install_result=$?
                            rm -f "$download_path"
                            
                            if [ $install_result -eq 0 ]; then
                                echo
                                echo "${bold}${green}✓${normal} Downgrade completed for $package."
                            else
                                echo
                                echo "Downgrade failed for $package."
                            fi
                        else
                            echo
                            echo "Download verification failed for $package."
                        fi
                    else
                        echo
                        echo "Failed to download $package from Arch Linux Archive."
                        echo "The file may no longer be available."
                    fi
                else
                    sudo pacman -U "$selected_version"
                    
                    if [ $? -eq 0 ]; then
                        echo
                        echo "${bold}${green}✓${normal} Downgrade completed for $package."
                    else
                        echo
                        echo "Downgrade failed for $package."
                    fi
                fi
                
                echo
                read -p "Press any key to continue..." -n 1 -s -r
            fi
        done
        
        clear_screen
        echo "All selected packages have been processed."
        rm -f /var/cache/spm/package-list-cache.txt
        
        echo
        if [ $CLI_MODE -eq 1 ]; then
            read -p "Press any key to return to downgrade menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            packages=""
            continue
        else
            read -p "Press any key to return to main menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            return
        fi
    done
}

clear_cache() {
    while true; do
        clear_screen
        
        local preview_width=$(get_preview_width)
        local preview_file="/var/cache/spm/preview_width"
        local resize_flag="/var/cache/spm/resize_flag"

        echo 0 > "$resize_flag"

        local menu_label
        local header_text
        if [ $CLI_MODE -eq 1 ]; then
            menu_label="← Exit"
            header_text="Select an option to clear cache - Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            header_text="Select an option to clear cache - Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local options=(
            "All + Latest [Confirm]"
            "All - Latest [Auto]"
            "Pacman Cache"
            "AUR Cache"
            "$menu_label"
        )

        local header_height=7
        local menu_height=$(($(tput lines) - $header_height - 1))

        while true; do
            preview_width=$(cat "$preview_file")
            
            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
   			    --no-highlight-line \
				--layout=reverse-list \
				--cycle \
				--no-input \
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
                        "All + Latest"*)
                            echo "sudo rm -f /var/cache/pacman/pkg/*.pkg.tar.*"
                            echo "yay -Scc --noconfirm"
                            ;;
                        "All - Latest"*)
                            echo "sudo pacman -Sc --noconfirm"
                            echo "yay -Sc --noconfirm"
                            ;;
                        "Pacman Cache"*)
                            echo "sudo pacman -Sc"
                            ;;
                        "AUR Cache"*)
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
                        echo "AUR package cache: $yay_pkg_size"
                    else
                        echo "AUR package cache: 0"
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
                --header="$header_text" \
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
                    if [ $CLI_MODE -eq 1 ]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi
            
            break
        done

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [ $CLI_MODE -eq 1 ]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

        local operation_cancelled=false

        case "$selected_option" in
            "All + Latest"*)
                echo "Clearing ALL package caches including latest versions..."
                echo
                
                local confirm
                if [ $CLI_MODE -eq 1 ]; then
                    trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                    read -p "This will remove ALL cached packages including latest versions. Continue? [y/N] " confirm
                    trap - INT
                else
                    (
                        trap 'exit 130' INT
                        read -p "This will remove ALL cached packages including latest versions. Continue? [y/N] " confirm
                        echo "$confirm" > /tmp/spm_cache_confirm_$$
                    )
                    if [ $? -eq 130 ]; then
                        echo
                        echo "Operation cancelled. Returning to menu..."
                        sleep 1
                        operation_cancelled=true
                    else
                        confirm=$(cat /tmp/spm_cache_confirm_$$ 2>/dev/null)
                        rm -f /tmp/spm_cache_confirm_$$
                    fi
                fi
                
                if ! $operation_cancelled; then
                    if [[ $confirm =~ ^[Yy]$ ]]; then
                        sudo rm -f /var/cache/pacman/pkg/*.pkg.tar.*
                        yay -Scc --noconfirm
                    else
                        echo "Operation cancelled."
                        sleep 1
                        operation_cancelled=true
                    fi
                fi
                ;;
            "All - Latest"*)
                echo "Performing cache clear (keeping latest versions)..."
                sudo pacman -Sc --noconfirm
                yay -Sc --noconfirm
                ;;
            "Pacman Cache"*)
                echo "Clearing Pacman cache..."
                sudo pacman -Sc
                ;;
            "AUR Cache"*)
                echo "Clearing AUR cache..."
                yay -Sc
                ;;
        esac

        if $operation_cancelled; then
            continue
        fi

        echo
        local remaining_cache=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
        echo "Operation completed. Remaining pacman cache size: $remaining_cache"
        echo
        
        if [ $CLI_MODE -eq 1 ]; then
            read -p "Press any key to return to cache menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            continue
        else
            read -p "Press any key to return to main menu or Ctrl+C to exit... " -n 1 -s -r
            echo
            return
        fi
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
        "← Menu") echo "Return to the main SPM menu.";;
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
    
    (
        trap 'exit 130' INT
        read -e -i "$current_value" -p "Enter new value or press Enter to keep current: " new_value
        echo "$new_value" > /tmp/spm_pacman_edit_$$
    )
    if [ $? -eq 130 ]; then
        echo
        echo "Operation cancelled."
        rm -f /tmp/spm_pacman_edit_$$
        sleep 1
        return
    fi
    new_value=$(cat /tmp/spm_pacman_edit_$$ 2>/dev/null)
    rm -f /tmp/spm_pacman_edit_$$

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
    
    local confirm
    (
        trap 'exit 130' INT
        read -p "Do you want to $new_status $option? [y/N] " confirm
        echo "$confirm" > /tmp/spm_pacman_toggle_$$
    )
    if [ $? -eq 130 ]; then
        echo
        echo "Operation cancelled."
        rm -f /tmp/spm_pacman_toggle_$$
        sleep 1
        return
    fi
    confirm=$(cat /tmp/spm_pacman_toggle_$$ 2>/dev/null)
    rm -f /tmp/spm_pacman_toggle_$$

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
   	    --no-highlight-line \
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
    
    (
        trap 'exit 130' INT
        read -p "Enter the name of the new repository: " repo_name
        echo "$repo_name" > /tmp/spm_repo_name_$$
    )
    if [ $? -eq 130 ]; then
        echo
        echo "Operation cancelled."
        rm -f /tmp/spm_repo_name_$$
        sleep 1
        return
    fi
    repo_name=$(cat /tmp/spm_repo_name_$$ 2>/dev/null)
    rm -f /tmp/spm_repo_name_$$
    
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
    
    (
        trap 'exit 130' INT
        read -p "Enter the server URL for the repository: " server_url
        echo "$server_url" > /tmp/spm_repo_url_$$
    )
    if [ $? -eq 130 ]; then
        echo
        echo "Operation cancelled."
        rm -f /tmp/spm_repo_url_$$
        sleep 1
        return
    fi
    server_url=$(cat /tmp/spm_repo_url_$$ 2>/dev/null)
    rm -f /tmp/spm_repo_url_$$
    
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
            "← Menu"
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
					--layout=reverse-list \
					--cycle \
                    --style=full:line \
   			        --no-highlight-line \
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
                    --header="Pacman Configuration Menu - Enter to select | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
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
            "← Menu")
                return
                ;;
        esac
    done
}

export -f get_recent_updates
export -f get_recent_installs
export -f get_recent_removals
export -f display_preview
export -f get_option_description
export -f display_pacman_conf

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
   			    --no-highlight-line \
				--layout=reverse-list \
				--cycle \
				--no-input \
				--preview-border=rounded \
                --header-border=line \
                --border-label=" SPM Main Menu " \
                --preview '
                    bold=$(tput bold)
                    normal=$(tput sgr0)
                    cyan=$(tput setaf 6)
                    green=$(tput setaf 2)
                    red=$(tput setaf 1)
                    
                    echo -e "${bold}${green}Recently Updated:${normal}"
                    get_recent_updates 15
                    echo
                    echo -e "${bold}${cyan}Recently Installed:${normal}"
                    get_recent_installs 15
                    echo
                    echo -e "${bold}${red}Recently Removed:${normal}"
                    get_recent_removals 15
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --preview-label=' Pacman Log ' \
                --header="Enter to select | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview" \
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

[ ! -f "$UPDATE_CACHE_FILE" ] && echo "0" > "$UPDATE_CACHE_FILE"
[ ! -f "$DETAILED_UPDATE_CACHE_FILE" ] && echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"

if [ $# -eq 0 ]; then
    manager
else
    CLI_MODE=1
    case "$1" in
        -u|update)
            update
            exit 0
            ;;
        -i|install)
            shift
            install "$*"
            exit 0
            ;;
        -r|remove)
            shift
            remove "$*"
            exit 0
            ;;
        -o|orphan)
            orphan
            exit 0
            ;;
        -d|downgrade)
            downgrade "$2"
            exit 0
            ;;
        -c|cache)
            clear_cache
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Invalid option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
fi