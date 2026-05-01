#!/bin/bash

# SPM - Simple Package Manager
# Dependencies: fzf (0.58.0+), yay

# Force fzf to use bash for preview commands (fixes fish/zsh compatibility)
export SHELL=/bin/bash

CLI_MODE=0

# Cache directory and file constants
SPM_CACHE_DIR="/var/cache/spm"
UPDATE_CACHE_FILE="$SPM_CACHE_DIR/update-cache.txt"
DETAILED_UPDATE_CACHE_FILE="$SPM_CACHE_DIR/detailed-update-cache.txt"
PACKAGE_LIST_CACHE="$SPM_CACHE_DIR/package-list-cache.txt"
HEADER_CACHE_FILE="$SPM_CACHE_DIR/header-cache.txt"
PREVIEW_WIDTH_FILE="$SPM_CACHE_DIR/preview_width"
RESIZE_FLAG_FILE="$SPM_CACHE_DIR/resize_flag"

export BOLD=$'\033[1m'
export CYAN=$'\033[36m'
export GREEN=$'\033[32m'
export YELLOW=$'\033[33m'
export RED=$'\033[31m'
export RESET=$'\033[0m'

FZF_RESIZE_BINDS=(
    --bind "alt-[:execute-silent(new_width=\$(cat $PREVIEW_WIDTH_FILE); new_width=\$((new_width + 10)); [ \$new_width -gt 90 ] && new_width=90; echo \$new_width > $PREVIEW_WIDTH_FILE; echo 1 > $RESIZE_FLAG_FILE)+abort"
    --bind "alt-]:execute-silent(new_width=\$(cat $PREVIEW_WIDTH_FILE); new_width=\$((new_width - 10)); [ \$new_width -lt 10 ] && new_width=10; echo \$new_width > $PREVIEW_WIDTH_FILE; echo 1 > $RESIZE_FLAG_FILE)+abort"
)

ensure_spm_var_dir() {
    if [[ ! -d "$SPM_CACHE_DIR" ]]; then
        sudo mkdir -p "$SPM_CACHE_DIR"
    fi
    if [[ ! -w "$SPM_CACHE_DIR" ]]; then
        sudo chmod 777 "$SPM_CACHE_DIR"
    fi
    for file in "$UPDATE_CACHE_FILE" "$DETAILED_UPDATE_CACHE_FILE"; do
        if [[ -f "$file" && ! -w "$file" ]]; then
            sudo chmod 666 "$file"
        fi
    done
}

ensure_spm_var_dir

spm_read_input() {
    local prompt="$1"
    local tmp rc
    tmp=$(mktemp /tmp/spm_input.XXXXXX)
    (
        trap 'exit 130' INT
        local val
        read -p "$prompt" val
        echo "$val" > "$tmp"
    )
    rc=$?
    if [[ $rc -eq 130 ]]; then
        rm -f "$tmp"
        return 130
    fi
    cat "$tmp"
    rm -f "$tmp"
}

clear_screen() {
    clear
    print_header
}

get_footer_color() {
    local color
    color=$(echo "$FZF_DEFAULT_OPTS" | grep -oP 'header[^,]*:#?\K[A-Fa-f0-9]{6}' | head -1)
    if [[ -n "$color" ]]; then
        echo "#$color"
    else
        echo "6"
    fi
}
FZF_FOOTER_COLOR=$(get_footer_color)

refresh_header_cache() {
    local packages
    local explicit
    packages=$(pacman -Qq | wc -l)
    explicit=$(pacman -Qeq | wc -l)
    echo "$packages $explicit" > "$HEADER_CACHE_FILE"
}

get_spm_header() {
    local packages explicit
    if [[ -f "$HEADER_CACHE_FILE" ]]; then
        read -r packages explicit < "$HEADER_CACHE_FILE"
        if ! [[ "$packages" =~ ^[0-9]+$ && "$explicit" =~ ^[0-9]+$ ]]; then
            packages=$(pacman -Qq | wc -l)
            explicit=$(pacman -Qeq | wc -l)
            echo "$packages $explicit" > "$HEADER_CACHE_FILE"
        fi
    else
        packages=$(pacman -Qq | wc -l)
        explicit=$(pacman -Qeq | wc -l)
        echo "$packages $explicit" > "$HEADER_CACHE_FILE"
    fi
    local updates=$(cat "$UPDATE_CACHE_FILE" 2>/dev/null || echo "0")
    [[ "$updates" =~ ^[0-9]+$ ]] || updates="0"
    local pacman_cache=$(get_pacman_cache_size)
    local yay_cache=$(get_yay_cache_size)

    printf " ___ ___ __  __\n"
    printf "/ __| _ \\\\  \\/  | \033[1m\033[36mSimple Package Manager\033[0m\n"
    printf "\\\\__ \\\\  _/ |\\/| | \033[1mPacman\033[0m %-9s \033[1mYay\033[0m %-9s\n" "$pacman_cache" "$yay_cache"
    printf "|___/_| |_|  |_| \033[1mPackages\033[0m %-5d \033[1mExplicit\033[0m %-5d \033[1mUpdates\033[0m %-5d\n" "$packages" "$explicit" "$updates"
    printf " \n"
}

get_preview_width() {
    if [[ ! -f "$PREVIEW_WIDTH_FILE" ]]; then
        echo "60" > "$PREVIEW_WIDTH_FILE"
    fi
    cat "$PREVIEW_WIDTH_FILE"
}

get_pacman_cache_size() {
    local size
    size=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
    if [[ -z "$size" || "$size" == "0" ]]; then
        echo "0"
    else
        echo "$size"
    fi
}

get_yay_cache_size() {
    local size
    size=$(du -sh "$HOME/.cache/yay" 2>/dev/null | cut -f1)
    if [[ -z "$size" || "$size" == "0" ]]; then
        echo "0"
    else
        echo "$size"
    fi
}

print_header() {
    get_spm_header
    echo
}

show_help() {
    clear_screen


    echo "${BOLD}${CYAN}SPM - Simple Package Manager${RESET}"
    echo "${BOLD}A modern TUI wrapper for pacman/yay with fzf${RESET}"
    echo
    echo "${BOLD}USAGE:${RESET}"
    echo "  spm [option] [arguments]"
    echo
    echo "${BOLD}OPTIONS:${RESET}"
    echo "  ${GREEN}-u${RESET}, ${GREEN}update${RESET}        Update packages"
    echo "  ${GREEN}-i${RESET}, ${GREEN}install${RESET}       Install packages"
    echo "  ${GREEN}-r${RESET}, ${GREEN}remove${RESET}        Remove packages"
    echo "  ${GREEN}-o${RESET}, ${GREEN}orphan${RESET}        Clean orphaned packages"
    echo "  ${GREEN}-d${RESET}, ${GREEN}downgrade${RESET}     Downgrade packages"
    echo "  ${GREEN}-c${RESET}, ${GREEN}cache${RESET}         Clear package cache"
    echo "  ${GREEN}-p${RESET}, ${GREEN}pacnew${RESET}        Manage .pacnew and .pacsave files"
    echo "  ${GREEN}-H${RESET}, ${GREEN}hooks${RESET}         Manage ALPM hooks"
    echo "  ${GREEN}-h${RESET}, ${GREEN}--help${RESET}        Display this help message"
    echo
    echo "${BOLD}EXAMPLES:${RESET}"
    echo "  ${YELLOW}spm${RESET}                   Launch interactive menu"
    echo "  ${YELLOW}spm -i firefox${RESET}        Install Firefox"
    echo "  ${YELLOW}spm -r firefox${RESET}        Remove Firefox"
    echo "  ${YELLOW}spm -u${RESET}                Update packages menu"
    echo
    echo "${BOLD}SYSTEMD TIMER:${RESET}"
    echo "  Enable automatic update checking and cache syncing:"
    echo "  ${YELLOW}systemctl enable --now spm_updates.timer${RESET}"
    echo
    echo "  Check timer status:"
    echo "  ${YELLOW}systemctl status spm_updates.timer${RESET}"
    echo
    echo "${BOLD}CONFIGURATION:${RESET}"
    echo "  Cache location:     /var/cache/spm/"
    echo "  pacman config:      /etc/pacman.conf"
    echo
    echo "For more information, visit:"
    echo "${CYAN}https://github.com/adelmonte/Simple_Package_Manager${RESET}"
    echo
}

update() {
    while true; do
        clear

        if [[ -t 0 ]]; then
            local preview_width=$(get_preview_width)

            echo 0 > "$RESIZE_FLAG_FILE"
        else
            local preview_width=50
        fi

        local menu_label
        local footer_text
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
            footer_text="Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            footer_text="Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local selected_option=$(printf '%s\n' \
            "All [Auto]" \
            "All [Review]" \
            "System [Review]" \
            "AUR-devel [Review]" \
            "$menu_label" |
            fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
                --preview-border=line \
                --header-border=line \
                --header-label=" Update Packages " \
                --header-label-pos=0:bottom \
                --preview '

                    echo
                    echo -e "${BOLD}${CYAN}Update Information${RESET}"
                    echo
                    echo -e "${BOLD}Command to execute:${RESET}"
                    case {} in
                        "All [Auto]"*)           echo "yes | yay" ;;
                        "All [Review]"*)         echo "yay" ;;
                        "System [Review]"*)      echo "yay -Syu" ;;
                        "AUR-devel"*)            echo "yay -Sua --devel" ;;
                        *)                       echo "No command to execute" ;;
                    esac
                    echo
                    echo -e "${BOLD}Upgradable Packages:${RESET}"
                    echo
                    cat "'$DETAILED_UPDATE_CACHE_FILE'" 2>/dev/null || echo "No update information available."
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --header="$(get_spm_header)" \
                --footer="$footer_text" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

        if [[ -z "$selected_option" ]]; then
            if [[ -t 0 ]] && [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                echo 0 > "$RESIZE_FLAG_FILE"
                continue
            else
                if [[ $CLI_MODE -eq 1 ]]; then
                    clear
                    echo "Exiting SPM - Simple Package Manager. Goodbye!"
                fi
                return
            fi
        fi

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
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
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f "$PACKAGE_LIST_CACHE"
                refresh_header_cache
                ;;
            "All [Review]"*)
                echo "Performing full update..."
                yay
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f "$PACKAGE_LIST_CACHE"
                refresh_header_cache
                ;;
            "System [Review]"*)
                echo "Updating system packages..."
                yay -Syu
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f "$PACKAGE_LIST_CACHE"
                refresh_header_cache
                ;;
            "AUR-devel"*)
                echo "Checking AUR development packages for updates..."
                yay -Sua --devel
                echo "0" > "$UPDATE_CACHE_FILE"
                echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"
                rm -f "$PACKAGE_LIST_CACHE"
                refresh_header_cache
                ;;
        esac

        trap - INT

        echo
        if [[ $CLI_MODE -eq 1 ]]; then
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
        local cache_file="$PACKAGE_LIST_CACHE"
        local installed_temp
        installed_temp=$(mktemp /tmp/spm_installed.XXXXXX)

        echo 0 > "$RESIZE_FLAG_FILE"

        local regenerate_cache=false

        if [[ ! -f "$cache_file" ]]; then
            regenerate_cache=true
        elif [[ $(wc -l < "$cache_file") -lt 100 ]] || grep -qP '\x00' "$cache_file" 2>/dev/null; then
            rm -f "$cache_file"
            regenerate_cache=true
        elif ! systemctl is-enabled spm_updates.timer &>/dev/null; then
            if [[ -n $(find /var/lib/pacman/sync -name '*.db' -newer "$cache_file" 2>/dev/null) ]]; then
                regenerate_cache=true
            elif [[ -z $(find "$cache_file" -mmin -60 2>/dev/null) ]]; then
                regenerate_cache=true
            fi
        fi

        if [[ "$regenerate_cache" == true ]]; then
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

            if ! systemctl is-enabled spm_updates.timer &>/dev/null; then
                echo
                echo "Note: Enable spm_updates.timer to keep the cache updated automatically:"
                echo "  systemctl enable --now spm_updates.timer"
                echo
                sleep 2
            fi
        fi

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected_packages=$(fzf --multi --reverse < "$cache_file" \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --scrollbar='█' \
                --preview-border=line \
                --border-label=" Install Packages " \
                --preview "

                    pkg_name=\$(echo {} | awk '{print \$1}')

                    if pacman -Qi \$pkg_name &>/dev/null; then
                        echo -e \"\${BOLD}\${GREEN}● Package Status: INSTALLED\${RESET}\"
                        echo
                        echo -e \"\${BOLD}\${CYAN}Package Information\${RESET}\"
                        yay -Qi \$pkg_name
                        echo
                        echo -e \"\${BOLD}Installed Files:\${RESET}\"
                        pacman -Ql \$pkg_name | grep -v '/\$' | cut -d' ' -f2- | head -50
                    else
                        echo -e \"\${BOLD}\${YELLOW}○ Package Status: NOT INSTALLED\${RESET}\"
                        echo
                        echo -e \"\${BOLD}\${CYAN}Package Information\${RESET}\"
                        yay -Si \$pkg_name
                    fi
                " \
                --preview-window="right:$preview_width%:wrap" \
                --header="Select package(s) to install | Tab to multi-select | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --tiebreak=index \
                --ansi \
                ${search_query:+-q "$search_query"} \
                | awk '{print $1}')

            if [[ -z "$selected_packages" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        echo
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi

            break
        done


        echo "${BOLD}${CYAN}The following packages will be installed:${RESET}"
        echo "$selected_packages" | sed "s/^/  ${GREEN}→${RESET} /"
        echo

        if [[ $CLI_MODE -eq 1 ]]; then
            trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
            read -p "${BOLD}Do you want to proceed? [Y/n]${RESET} " confirm
            trap - INT
        else
            confirm=$(spm_read_input "${BOLD}Do you want to proceed? [Y/n]${RESET} ") || {
                echo
                echo "Operation cancelled. Returning to package selection..."
                sleep 1
                continue
            }
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
                refresh_header_cache
                echo
                if [[ $CLI_MODE -eq 1 ]]; then
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


        local search_query="$1"
        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local selected_packages=$(pacman -Qq | fzf --multi --reverse \
            --style=full:line \
            --no-highlight-line \
            --cycle \
            --scrollbar='█' \
            --preview-border=line \
            --border-label=" Remove Packages " \
            --preview '

                pkg_info=$(yay -Qi {1} 2>/dev/null)

                echo -e "${BOLD}${RED}⚠ Package Information: {1}${RESET}"
                echo
                echo -e "${BOLD}${CYAN}Package Information${RESET}"
                echo "$pkg_info"
                echo
                echo -e "${BOLD}${YELLOW}Required By:${RESET}"
                echo "$pkg_info" | grep "Required By" | cut -d":" -f2
                echo
                echo -e "${BOLD}Installed Files:${RESET}"
                pacman -Ql {1} | grep -v "/$" | cut -d" " -f2- | head -100
            ' \
            --preview-window="right:$preview_width%:wrap" \
            --header="Select package(s) to remove | Tab to multi-select | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
            --bind 'ctrl-c:abort' \
            --bind 'resize:refresh-preview' \
            "${FZF_RESIZE_BINDS[@]}" \
            --ansi \
            ${search_query:+-q "$search_query"})

        if [[ -z "$selected_packages" ]]; then
            if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                echo 0 > "$RESIZE_FLAG_FILE"
                continue
            else
                if [[ $CLI_MODE -eq 1 ]]; then
                    echo
                    echo "Exiting SPM - Simple Package Manager. Goodbye!"
                fi
                return
            fi
        fi

        echo "${BOLD}${CYAN}The following packages will be removed:${RESET}"
        echo "$selected_packages" | sed 's/^/  → /' | while read line; do
            echo -e "${RED}${line}${RESET}"
        done
        echo

        echo "${BOLD}Package Removal Options:${RESET}"
        echo "------------------------"
        echo

        local pacman_args=""

        echo "  ${BOLD}1)${RESET} Full removal (package, deps, configs, and reverse deps) ${YELLOW}-Rnsc${RESET}"
        echo "  ${BOLD}2)${RESET} Standard removal (package, deps, and configs) ${YELLOW}-Rns${RESET}"
        echo "  ${BOLD}3)${RESET} Remove package and configs only ${YELLOW}-Rn${RESET}"
        echo "  ${BOLD}4)${RESET} Remove package and dependencies ${YELLOW}-Rs${RESET}"
        echo "  ${BOLD}5)${RESET} Remove package only ${YELLOW}-R${RESET}"
        echo "  ${BOLD}6)${RESET} Force removal ignoring dependencies ${YELLOW}-Rdd${RESET} ${RED}(dangerous)${RESET}"
        echo "  ${BOLD}7)${RESET} Force removal with configs ${YELLOW}-Rddn${RESET} ${RED}(dangerous)${RESET}"
        echo

        if [[ $CLI_MODE -eq 1 ]]; then
            trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
            read -p "Enter option 1-7 [1] (Ctrl+C to cancel): " remove_option
            trap - INT
        else
            remove_option=$(spm_read_input "Enter option 1-7 [1] (Ctrl+C to cancel): ") || {
                echo
                echo "Operation cancelled. Returning to package selection..."
                sleep 1
                continue
            }
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
                rm -f "$PACKAGE_LIST_CACHE"
                refresh_header_cache
                echo
                if [[ $CLI_MODE -eq 1 ]]; then
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
        clear_screen


        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local package_list=$(pacman -Qd | awk '{print $1}')
            local selected_package=$(echo "$package_list" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --scrollbar='█' \
                --preview-border=line \
                --border-label=" Explore Dependencies " \
                --preview '

                    pkg_info=$(pacman -Qi {1} 2>/dev/null)

                    echo -e "${BOLD}${CYAN}Package: {1}${RESET}"
                    echo
                    echo -e "${BOLD}Description:${RESET}"
                    echo "$pkg_info" | grep "Description" | cut -d":" -f2-
                    echo
                    echo -e "${BOLD}${GREEN}Required By:${RESET}"
                    echo "Packages that depend on this:"
                    req_by=$(echo "$pkg_info" | grep "Required By" | cut -d":" -f2-)
                    if [[ "$req_by" == *"None"* ]]; then
                        echo "  ${GREEN}None - can be safely removed${RESET}"
                    else
                        echo "$req_by" | tr " " "\n" | sed "s/^/  /"
                    fi
                    echo
                    echo -e "${BOLD}${YELLOW}Dependencies:${RESET}"
                    echo "This package depends on:"
                    echo "$pkg_info" | grep "Depends On" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --header="Select a dependency package to explore | Enter to view details | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --ansi)

            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    return
                fi
            fi

            clear_screen
            echo "${BOLD}${CYAN}Package: $selected_package${RESET}"
            echo "Description: $(pacman -Qi $selected_package | grep "Description" | cut -d":" -f2-)"
            echo
            echo "${BOLD}${GREEN}Required By:${RESET}"
            echo "Packages that depend on this:"
            pacman -Qi $selected_package | grep "Required By" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            echo "${BOLD}${YELLOW}Dependencies:${RESET}"
            echo "This package depends on:"
            pacman -Qi $selected_package | grep "Depends On" | cut -d":" -f2- | tr " " "\n" | sed "s/^/  /"
            echo
            read -p "Press any key to continue exploring or Ctrl+C to return... " -n 1 -s -r
            break
        done
    done
}

find_high_impact_removals() {
    clear_screen

    local temp_file=$(mktemp)


    echo "${BOLD}${CYAN}Analyzing High-Impact Removals...${RESET}"
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

            if [[ -z "$removal_list" ]]; then
                exit 0
            fi

            conflict=false
            for removed_pkg in $removal_list; do
                if [[ "$removed_pkg" != "$pkg" ]] && [[ " $explicit_list " =~ " $removed_pkg " ]]; then
                    conflict=true
                    break
                fi
            done

            if [[ "$conflict" == false ]]; then
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

    if [[ ! -s "$temp_file" ]]; then
        echo "${YELLOW}No high-impact removal candidates found.${RESET}"
        rm "$temp_file"
        read -p "Press any key to return... " -n 1 -s -r
        return
    fi

    local preview_width=$(get_preview_width)

    echo 0 > "$RESIZE_FLAG_FILE"

    while true; do
        preview_width=$(cat "$PREVIEW_WIDTH_FILE")

        local selected_line=$(fzf --reverse < "$temp_file" \
            --style=full:line \
            --no-highlight-line \
            --cycle \
            --scrollbar='█' \
            --preview-border=line \
            --border-label=" High-Impact Removals " \
            --preview '

                pkg=$(echo {} | awk "{print \$2}")
                count=$(echo {} | awk "{print \$1}")

                pkg_info=$(pacman -Qi "$pkg" 2>/dev/null)

                echo -e "${BOLD}${CYAN}$pkg${RESET}"
                echo
                echo "$pkg_info" | grep "Description" | cut -d":" -f2-
                echo
                echo -e "${BOLD}${YELLOW}Would remove $count package(s)${RESET}"
                echo
                echo -e "${BOLD}${GREEN}Install Reason:${RESET}"
                echo "$pkg_info" | grep "Install Reason" | cut -d":" -f2-
                echo
                echo -e "${BOLD}Dependencies to be removed:${RESET}"
                removal_list=$(pacman -Rsp "$pkg" 2>/dev/null)
                echo "$removal_list" | head -30 | sed "s/^/  /"
                removal_count=$(echo "$removal_list" | wc -l)
                if [[ "$removal_count" -gt 30 ]]; then
                    echo "  ... and $((removal_count - 30)) more"
                fi
                echo
                echo -e "${BOLD}Install Information:${RESET}"
                echo "$pkg_info" | grep -E "Install Date|Installed Size" | sed "s/^/  /"
            ' \
            --preview-window="right:${preview_width}%:wrap" \
            --header="High-impact removal candidates | Enter to view details | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
            --bind 'ctrl-c:abort' \
            --bind 'resize:refresh-preview' \
            "${FZF_RESIZE_BINDS[@]}" \
            --ansi)

        if [[ -z "$selected_line" ]]; then
            if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                echo 0 > "$RESIZE_FLAG_FILE"
                continue
            else
                rm "$temp_file"
                return
            fi
        fi

        local selected_package=$(echo "$selected_line" | awk '{print $2}')
        local removed_count=$(echo "$selected_line" | awk '{print $1}')

        clear_screen
        echo "${BOLD}${CYAN}Package: $selected_package${RESET}"
        echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2-)"
        echo
        echo "${BOLD}${GREEN}Install Reason:${RESET}"
        pacman -Qi "$selected_package" | grep "Install Reason" | cut -d":" -f2-
        echo
        echo "${BOLD}${YELLOW}Would remove $removed_count package(s)${RESET}"
        echo
        echo "${BOLD}Dependencies to be removed:${RESET}"
        pacman -Rsp "$selected_package" 2>/dev/null | sed 's/^/  /'
        echo
        echo "${BOLD}Install Information:${RESET}"
        pacman -Qi "$selected_package" | grep -E "Install Reason|Install Date|Installed Size" | sed 's/^/  /'
        echo
        read -p "Press any key to return to package list... " -n 1 -s -r
    done
}

browse_explicit_packages() {
    while true; do
        clear_screen


        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local explicit_tmp
        explicit_tmp=$(mktemp /tmp/spm_explicit.XXXXXX)
        pacman -Qeq > "$explicit_tmp"

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected_package=$(fzf --reverse < "$explicit_tmp" \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --scrollbar='█' \
                --preview-border=line \
                --border-label=" Explicitly Installed Packages " \
                --preview "

                    pkg={1}

                    echo -e \"\${BOLD}\${CYAN}\$pkg\${RESET}\"
                    echo
                    pkg_info=\$(pacman -Qi \"\$pkg\" 2>/dev/null)
                    echo \"\$pkg_info\" | grep 'Description' | cut -d':' -f2-
                    echo
                    echo -e \"\${BOLD}\${YELLOW}Removal Impact:\${RESET}\"

                    removal_list=\$(pacman -Rsp \"\$pkg\" 2>/dev/null)
                    removed_count=\$(echo \"\$removal_list\" | wc -l)

                    explicit_list=\$(tr '\n' ' ' < '$explicit_tmp')

                    conflict=false
                    for removed in \$removal_list; do
                        if [[ \"\$removed\" != \"\$pkg\" ]] && [[ \" \$explicit_list \" =~ \" \$removed \" ]]; then
                            conflict=true
                            break
                        fi
                    done

                    if [[ \"\$conflict\" == true ]]; then
                        echo -e \"\${RED}Would remove other explicit packages\${RESET}\"
                    else
                        echo -e \"Would remove \${YELLOW}\$removed_count\${RESET} total packages\"
                    fi
                    echo
                    echo -e \"\${BOLD}Dependencies to be removed:\${RESET}\"
                    echo \"\$removal_list\" | head -30 | sed 's/^/  /'
                    if [[ \"\$removed_count\" -gt 30 ]]; then
                        echo \"  ... and \$((\$removed_count - 30)) more\"
                    fi
                    echo
                    echo -e \"\${BOLD}Installed:\${RESET}\"
                    echo \"\$pkg_info\" | grep 'Install Date' | cut -d':' -f2- | sed 's/^/  /'
                    echo -e \"\${BOLD}Size:\${RESET}\"
                    echo \"\$pkg_info\" | grep 'Installed Size' | cut -d':' -f2- | sed 's/^/  /'
                " \
                --preview-window="right:${preview_width}%:wrap" \
                --header="Browse explicitly installed packages | Enter to view details | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --ansi)

            if [[ -z "$selected_package" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    rm -f "$explicit_tmp"
                    return
                fi
            fi

            rm -f "$explicit_tmp"
            clear_screen
            echo "${BOLD}${CYAN}Package: $selected_package${RESET}"
            echo "Description: $(pacman -Qi "$selected_package" | grep "Description" | cut -d":" -f2-)"
            echo
            echo "${BOLD}${YELLOW}Removal Impact:${RESET}"

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

            if [[ "$conflict" == true ]]; then
                echo -e "${RED}Would remove other explicitly installed packages${RESET}"
            else
                echo -e "Would remove ${YELLOW}$removed_count${RESET} total packages"
            fi

            echo
            echo "${BOLD}Dependencies to be removed:${RESET}"
            echo "$removal_list" | sed 's/^/  /'
            echo
            echo "${BOLD}Install Information:${RESET}"
            pacman -Qi "$selected_package" | grep -E "Install Reason|Install Date|Installed Size" | sed 's/^/  /'
            echo
            read -p "Press any key to continue or Ctrl+C to return... " -n 1 -s -r
            break
        done
    done
}

dependencies_menu() {
    while true; do
        clear

        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local menu_label
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
        else
            menu_label="← Menu"
        fi

        local options=(
            "Explore Dependencies"
            "High-Impact Removals"
            "Browse Explicit Packages"
            "$menu_label"
        )
        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local spm_header
            spm_header=$(get_spm_header)

            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
                --preview-border=line \
                --header-border=line \
                --header-label=" Dependencies " \
                --header-label-pos=0:bottom \
                --preview '

                    echo
                    echo -e "${BOLD}${CYAN}Option Information${RESET}"
                    echo
                    case {} in
                        "Explore Dependencies")
                            echo -e "${BOLD}Explore Dependencies${RESET}"
                            echo
                            echo "Browse dependency packages and examine relationships."
                            echo
                            echo -e "${BOLD}What this does:${RESET}"
                            echo "• Lists packages installed as dependencies"
                            echo "• Shows which packages require each dependency"
                            echo "• Displays dependencies of each package"
                            echo
                            echo -e "${BOLD}Use case:${RESET}"
                            echo "Understanding package dependency relationships."
                            ;;
                        "High-Impact Removals")
                            echo -e "${BOLD}High-Impact Removals${RESET}"
                            echo
                            echo "Find all packages that would remove the most"
                            echo "dependencies without affecting explicitly installed packages."
                            echo
                            echo -e "${BOLD}What this does:${RESET}"
                            echo "• Analyzes ALL installed packages (explicit + deps)"
                            echo "• Counts dependencies that would be removed"
                            echo "• Filters out removals affecting explicit packages"
                            echo "• Searchable and sortable by impact"
                            echo
                            echo -e "${BOLD}Use case:${RESET}"
                            echo "Finding orphaned or safe-to-remove packages for cleanup."
                            ;;
                        "Browse Explicit Packages")
                            echo -e "${BOLD}Browse Explicit Packages${RESET}"
                            echo
                            echo "Browse all explicitly installed packages and examine"
                            echo "what would be removed with each one."
                            echo
                            echo -e "${BOLD}What this does:${RESET}"
                            echo "• Lists all explicitly installed packages"
                            echo "• Shows removal impact for each package"
                            echo "• Indicates if removal would affect other explicit packages"
                            echo "• Displays full removal list"
                            echo
                            echo -e "${BOLD}Use case:${RESET}"
                            echo "Exploring removal options for explicit packages."
                            ;;
                        *)
                            echo "Return to the main menu"
                            ;;
                    esac
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --header="${spm_header}" \
                --footer="Select an option | Enter to select | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi

            break
        done

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

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
        esac
    done
}

orphan() {
    while true; do
        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local menu_label
        local footer_text
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
            footer_text="Select an option | Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            footer_text="Select an option | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local options=(
            "All Orphans [Auto]"
            "Orphaned Only [Review]"
            "Unneeded Only [Review]"
            "Both Types [Review]"
            "$menu_label"
        )

        local orphan_preview orphan_tmp_a orphan_tmp_b
        orphan_preview=$(mktemp /tmp/spm_orphan_preview.XXXXXX)
        orphan_tmp_a=$(mktemp /tmp/spm_orphan_a.XXXXXX)
        orphan_tmp_b=$(mktemp /tmp/spm_orphan_b.XXXXXX)

        pacman -Qdtq 2>/dev/null > "$orphan_tmp_a" &
        local pid1=$!
        (pacman -Qqd 2>/dev/null | xargs pacman -Rsu --print 2>/dev/null | grep "^  " | awk '{print $1}') > "$orphan_tmp_b" &
        local pid2=$!
        wait $pid1 $pid2

        local orphan_data
        orphan_data=$(< "$orphan_tmp_a")
        local unneeded_data
        unneeded_data=$(< "$orphan_tmp_b")
        rm -f "$orphan_tmp_a" "$orphan_tmp_b"

        local orphan_count=0
        if [[ -n "$orphan_data" ]]; then
            orphan_count=$(echo "$orphan_data" | wc -l)
        fi
        local unneeded_count=0
        if [[ -n "$unneeded_data" ]]; then
            unneeded_count=$(echo "$unneeded_data" | wc -l)
        fi

        {
            printf '\033[1m\033[33mOrphaned Packages:\033[0m\n'
            echo "Installed as dependencies but no longer required"
            if [[ "$orphan_count" -gt 0 ]]; then
                echo "Count: $orphan_count"
                echo
                echo "$orphan_data" | head -20
                if [[ $orphan_count -gt 20 ]]; then
                    echo "... and $((orphan_count - 20)) more"
                fi
            else
                echo "Count: 0"
                echo
                echo "None found"
            fi
            echo
            printf '\033[1m\033[31mUnneeded Packages:\033[0m\n'
            echo "Dependencies not required by explicitly installed packages"
            if [[ "$unneeded_count" -gt 0 ]]; then
                echo "Count: $unneeded_count"
                echo
                echo "$unneeded_data" | head -20
                if [[ $unneeded_count -gt 20 ]]; then
                    echo "... and $((unneeded_count - 20)) more"
                fi
            else
                echo "Count: 0"
                echo
                echo "None found"
            fi
        } > "$orphan_preview"

        local spm_header
        spm_header=$(get_spm_header)

        clear

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
                --preview-border=line \
                --header-label=" Clean Orphans " \
                --header-label-pos=0:bottom \
                --header-border=line \
                --preview "
                    echo
                    printf '\033[1m\033[36mClean Orphans Information\033[0m\n'
                    echo
                    printf '\033[1mCommand to execute:\033[0m\n'
                    case {} in
                        'All Orphans [Auto]'*)
                            echo 'sudo pacman -Rns \$(pacman -Qdtq) --noconfirm'
                            echo 'sudo pacman -Rsu \$(pacman -Qqd) --noconfirm'
                            ;;
                        'Orphaned Only'*)
                            echo 'sudo pacman -Rns \$(pacman -Qdtq)'
                            ;;
                        'Unneeded Only'*)
                            echo 'sudo pacman -Rsu \$(pacman -Qqd)'
                            ;;
                        'Both Types'*)
                            echo 'sudo pacman -Rns \$(pacman -Qdtq)'
                            echo 'sudo pacman -Rsu \$(pacman -Qqd)'
                            ;;
                        *)
                            echo 'No command to execute'
                            ;;
                    esac
                    echo
                    cat '$orphan_preview'
                " \
                --preview-window="right:${preview_width}%:wrap" \
                --header="${spm_header}" \
                --footer="$footer_text" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    rm -f "$orphan_preview"
                    return
                fi
            fi

            break
        done

        rm -f "$orphan_preview"

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

        local operation_cancelled=false


        case "$selected_option" in
            "All Orphans [Auto]"*)
                echo "Performing quick removal..."
                [[ -n "$orphan_data" ]] && sudo pacman -Rns $orphan_data --noconfirm 2>/dev/null
                sudo pacman -Rsu $(pacman -Qqd) --noconfirm 2>/dev/null
                echo "Removal complete."
                ;;
            "Orphaned Only"*)
                if [[ -n "$orphan_data" ]]; then
                    echo "${BOLD}${CYAN}The following orphaned packages will be removed:${RESET}"
                    echo "$orphan_data" | sed 's/^/  → /'
                    echo

                    local confirm
                    if [[ $CLI_MODE -eq 1 ]]; then
                        trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                        read -p "Do you want to proceed? [Y/n] " confirm
                        trap - INT
                    else
                        confirm=$(spm_read_input "Do you want to proceed? [Y/n] ") || {
                            echo
                            echo "Operation cancelled. Returning to menu..."
                            sleep 1
                            operation_cancelled=true
                        }
                    fi

                    if ! $operation_cancelled; then
                        if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                            sudo pacman -Rns $orphan_data
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
                local unneeded="$unneeded_data"
                if [[ -n "$unneeded" ]]; then
                    echo "${BOLD}${CYAN}The following unneeded packages will be removed:${RESET}"
                    echo "$unneeded" | sed 's/^/  → /'
                    echo

                    local confirm
                    if [[ $CLI_MODE -eq 1 ]]; then
                        trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                        read -p "Do you want to proceed? [Y/n] " confirm
                        trap - INT
                    else
                        confirm=$(spm_read_input "Do you want to proceed? [Y/n] ") || {
                            echo
                            echo "Operation cancelled. Returning to menu..."
                            sleep 1
                            operation_cancelled=true
                        }
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
                local orphans="$orphan_data"
                local unneeded="$unneeded_data"

                if [[ -n "$orphans" || -n "$unneeded" ]]; then
                    echo "${BOLD}${CYAN}The following packages will be removed:${RESET}"
                    if [[ -n "$orphans" ]]; then
                        echo
                        echo "Orphaned packages:"
                        echo "$orphans" | sed 's/^/  → /'
                    fi
                    if [[ -n "$unneeded" ]]; then
                        echo
                        echo "Unneeded packages:"
                        echo "$unneeded" | sed 's/^/  → /'
                    fi
                    echo

                    local confirm
                    if [[ $CLI_MODE -eq 1 ]]; then
                        trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                        read -p "Do you want to proceed? [Y/n] " confirm
                        trap - INT
                    else
                        confirm=$(spm_read_input "Do you want to proceed? [Y/n] ") || {
                            echo
                            echo "Operation cancelled. Returning to menu..."
                            sleep 1
                            operation_cancelled=true
                        }
                    fi

                    if ! $operation_cancelled; then
                        if [[ ! $confirm =~ ^[Nn]o?$ ]]; then
                            [[ -n "$orphans" ]] && sudo pacman -Rns $orphans
                            [[ -n "$unneeded" ]] && sudo pacman -Rsu $(pacman -Qqd) 2>/dev/null
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

        rm -f "$PACKAGE_LIST_CACHE"

        echo
        if [[ $CLI_MODE -eq 1 ]]; then
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
        echo 0 > "$RESIZE_FLAG_FILE"

        local header_text
        if [[ $CLI_MODE -eq 1 ]]; then
            header_text="Select package(s) to downgrade | Tab to multi-select | Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            header_text="Select package(s) to downgrade | Tab to multi-select | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        if [[ -z "$packages" ]]; then
            while true; do
                preview_width=$(cat "$PREVIEW_WIDTH_FILE")

                packages=$(pacman -Qq | fzf --reverse --multi \
                    --style=full:line \
                    --no-highlight-line \
                    --cycle \
                    --scrollbar='█' \
                    --preview-border=line \
                    --border-label=" Downgrade Packages " \
                    --preview '

                        echo -e "${BOLD}${YELLOW}⬇ Downgrade: {}${RESET}"
                        echo
                        echo -e "${BOLD}${CYAN}Current Package Version${RESET}"
                        pacman -Qi {} 2>/dev/null || echo "Package not found"
                    ' \
                    --preview-window="right:$preview_width%:wrap" \
                    --header="$header_text" \
                    --bind 'ctrl-c:abort' \
                    --bind 'resize:refresh-preview' \
                    "${FZF_RESIZE_BINDS[@]}" \
                    --ansi)

                if [[ -z "$packages" ]]; then
                    if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                        echo 0 > "$RESIZE_FLAG_FILE"
                        continue
                    else
                        if [[ $CLI_MODE -eq 1 ]]; then
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


            echo "${BOLD}${YELLOW}⬇ Downgrading: $package${RESET}"
            echo

            if ! pacman -Qi "$package" > /dev/null 2>&1; then
                echo "Package $package is not installed. Skipping..."
                sleep 2
                continue
            fi

            local current_version=$(pacman -Q "$package" 2>/dev/null | awk '{print $2}')
            echo "${BOLD}Current version:${RESET} ${GREEN}$current_version${RESET}"
            echo
            echo "Searching for available versions..."

            local arch=$(uname -m)
            local candidates=()
            local cache_versions=()
            local ala_versions=()

            cache_versions=($(find /var/cache/pacman/pkg/ -maxdepth 1 -name "${package}-[0-9]*.pkg.tar.*" ! -name "*.sig" 2>/dev/null | sort -V -r))

            if [[ ${#cache_versions[@]} -gt 0 ]]; then
                echo "Found ${#cache_versions[@]} cached version(s)"
                candidates+=("${cache_versions[@]}")
            fi

            echo "Searching Arch Linux Archive..."
            local ala_list=$(curl -s "https://archive.archlinux.org/packages/${package:0:1}/$package/" 2>/dev/null | \
                grep -oP "${package}-[0-9][^\"]*\.pkg\.tar\.[^\"]*(?=\")" | \
                grep -v "\.sig$" | \
                grep -E "(${arch}|any)\.pkg\.tar\." | \
                sort -V -r)

            if [[ -n "$ala_list" ]]; then
                while IFS= read -r ver; do
                    ala_versions+=("ALA:$ver")
                done <<< "$ala_list"
                echo "Found ${#ala_versions[@]} version(s) in Arch Linux Archive"
                candidates+=("${ala_versions[@]}")
            fi

            if [[ ${#candidates[@]} -eq 0 ]]; then
                echo
                echo "No versions found for $package."
                echo "This could mean:"
                echo "  • The package is from AUR (not in official repos)"
                echo "  • No cached versions exist locally"
                echo "  • Network connectivity issues"
                echo
                read -p "Press any key to continue... " -n 1 -s -r
                continue
            fi

            echo
            echo "Total available versions: ${#candidates[@]}"
            echo

            while true; do
                preview_width=$(cat "$PREVIEW_WIDTH_FILE")

                local selected_version=$(printf '%s\n' "${candidates[@]}" | fzf --reverse \
                    --style=full:line \
                    --no-highlight-line \
                    --scrollbar='█' \
                    --preview-border=line \
                    --cycle \
                    --border-label=" Select Version for $package " \
                    --preview "

                        echo -e \"\${BOLD}\${YELLOW}⬇ Downgrading: $package\${RESET}\"
                        echo
                        echo -e \"\${BOLD}Current version:\${RESET} \${GREEN}$current_version\${RESET}\"
                        echo
                        echo -e \"\${BOLD}\${CYAN}Selected Version\${RESET}\"

                        version={}
                        if [[ \$version == ALA:* ]]; then
                            version=\${version#ALA:}
                            echo -e \"\${BOLD}Source:\${RESET} Arch Linux Archive\"
                            echo -e \"\${BOLD}File:\${RESET} \$version\"
                            echo
                            echo \"This version will be downloaded before installation.\"
                        else
                            echo -e \"\${BOLD}Source:\${RESET} Local cache\"
                            echo -e \"\${BOLD}Location:\${RESET} \$version\"
                            echo
                            echo -e \"\${BOLD}Package Information:\${RESET}\"
                            pacman -Qip \"\$version\" 2>/dev/null || echo 'Details not available'
                        fi
                    " \
                    --preview-window="right:$preview_width%:wrap" \
                    --header="Select a version to downgrade $package | Enter to confirm | Ctrl+C to skip
Alt+[ increase preview | Alt+] decrease preview" \
                    --bind 'ctrl-c:abort' \
                    --bind 'resize:refresh-preview' \
                    "${FZF_RESIZE_BINDS[@]}" \
                    --ansi)

                if [[ -z "$selected_version" ]]; then
                    if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                        echo 0 > "$RESIZE_FLAG_FILE"
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

            if [[ -n "$selected_version" ]]; then
                echo

                if [[ "$selected_version" == ALA:* ]]; then
                    local filename="${selected_version#ALA:}"
                    local download_path="/tmp/$filename"

                    echo "Downloading $filename from Arch Linux Archive..."
                    if wget -q --show-progress "https://archive.archlinux.org/packages/${package:0:1}/$package/$filename" -O "$download_path" 2>/dev/null; then
                        if [[ -f "$download_path" ]]; then
                            echo
                            sudo pacman -U "$download_path"
                            local install_result=$?
                            rm -f "$download_path"

                            if [[ $install_result -eq 0 ]]; then
                                echo
                                echo "${BOLD}${GREEN}✓${RESET} Downgrade completed for $package."
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

                    if [[ $? -eq 0 ]]; then
                        echo
                        echo "${BOLD}${GREEN}✓${RESET} Downgrade completed for $package."
                    else
                        echo
                        echo "Downgrade failed for $package."
                    fi
                fi

                echo
                read -p "Press any key to continue... " -n 1 -s -r
            fi
        done

        clear_screen
        echo "All selected packages have been processed."
        rm -f "$PACKAGE_LIST_CACHE"
        refresh_header_cache

        echo
        if [[ $CLI_MODE -eq 1 ]]; then
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
        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local menu_label
        local footer_text
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
            footer_text="Select an option | Enter to confirm | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            footer_text="Select an option | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local options=(
            "All - Latest [Auto]"
            "All + Latest [Confirm]"
            "Pacman Cache"
            "AUR Cache"
            "$menu_label"
        )

        local spm_header
        spm_header=$(get_spm_header)

        clear

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
                --preview-border=line \
                --header-border=line \
                --header-label=" Clear Package Cache " \
                --header-label-pos=0:bottom \
                --preview "
                    echo
                    printf '\033[1m\033[36mClear Cache Information\033[0m\n'
                    echo
                    printf '\033[1mCommand to execute:\033[0m\n'
                    case {} in
                        'All + Latest'*)
                            echo 'sudo rm -f /var/cache/pacman/pkg/*.pkg.tar.*'
                            echo 'yay -Scc --noconfirm'
                            ;;
                        'All - Latest'*)
                            echo 'sudo pacman -Sc --noconfirm'
                            echo 'yay -Sc --noconfirm'
                            ;;
                        'Pacman Cache'*)
                            echo 'sudo pacman -Sc'
                            ;;
                        'AUR Cache'*)
                            echo 'yay -Sc'
                            ;;
                        *)
                            echo 'No command to execute'
                            ;;
                    esac
                    echo
                    printf '\033[1m\033[33mCurrent Cache Sizes:\033[0m\n'
                    pacman_cache=\$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
                    echo \"pacman cache: \$pacman_cache\"
                    yay_pkg_size=\$(du -sh ~/.cache/yay 2>/dev/null | cut -f1)
                    if [[ -n \"\$yay_pkg_size\" && \"\$yay_pkg_size\" != '0' ]]; then
                        echo \"AUR cache: \$yay_pkg_size\"
                    else
                        echo 'AUR cache: 0'
                    fi
                    echo
                    printf '\033[1mPacman Cache Details:\033[0m\n'
                    total_pkgs=\$(find /var/cache/pacman/pkg -maxdepth 1 -name '*.pkg.tar.*' 2>/dev/null | wc -l)
                    unique_pkgs=\$(find /var/cache/pacman/pkg -maxdepth 1 -name '*.pkg.tar.*' 2>/dev/null | sed 's/-[0-9].*\$//' | sort -u | wc -l)
                    echo \"Total packages: \$total_pkgs\"
                    echo \"Unique packages: \$unique_pkgs\"
                    echo
                    printf '\033[1mDisk Usage:\033[0m\n'
                    df -h / | awk 'NR==2 {print \"Used: \" \$3 \" of \" \$2 \" - \" \$5; print \"Available: \" \$4}'
                " \
                --preview-window="right:${preview_width}%:wrap" \
                --header="${spm_header}" \
                --footer="$footer_text" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi

            break
        done

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
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
                if [[ $CLI_MODE -eq 1 ]]; then
                    trap 'echo; echo "Operation cancelled."; echo; echo "Exiting SPM - Simple Package Manager. Goodbye!"; exit 0' INT
                    read -p "This will remove ALL cached packages including latest versions. Continue? [y/N] " confirm
                    trap - INT
                else
                    confirm=$(spm_read_input "This will remove ALL cached packages including latest versions. Continue? [y/N] ") || {
                        echo
                        echo "Operation cancelled. Returning to menu..."
                        sleep 1
                        operation_cancelled=true
                    }
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
                echo "Clearing pacman cache..."
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

        if [[ $CLI_MODE -eq 1 ]]; then
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

pacnew_pacsave_manager() {
    while true; do
        clear

        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local menu_label
        local footer_text
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
            footer_text="Select a file to manage | Enter to select | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            footer_text="Select a file to manage | Enter to select | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local config_files=$(sudo find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null | sort)

        if [[ -z "$config_files" ]]; then
            echo "No .pacnew or .pacsave files found."
            echo
            if [[ $CLI_MODE -eq 1 ]]; then
                read -p "Press any key to exit... " -n 1 -s -r
                echo
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            else
                read -p "Press any key to return to menu... " -n 1 -s -r
                echo
            fi
            return
        fi

        local pacnew_count=$(echo "$config_files" | grep -c '\.pacnew$' || true)
        local pacsave_count=$(echo "$config_files" | grep -c '\.pacsave$' || true)

        local file_list=""

        if [[ "$pacnew_count" -gt 0 ]]; then
            file_list="[BULK] Delete All Pacnew ($pacnew_count files)
[BULK] Apply All Pacnew ($pacnew_count files)"
        fi
        if [[ "$pacsave_count" -gt 0 ]]; then
            if [[ -n "$file_list" ]]; then
                file_list="$file_list
[BULK] Delete All Pacsave ($pacsave_count files)"
            else
                file_list="[BULK] Delete All Pacsave ($pacsave_count files)"
            fi
        fi

        local individual_files=$(echo "$config_files" | while read -r file; do
            if [[ "$file" == *.pacnew ]]; then
                echo "[PACNEW] $file"
            else
                echo "[PACSAVE] $file"
            fi
        done)

        if [[ -n "$file_list" ]]; then
            file_list=$(printf '%s\n%s\n%s' "$file_list" "$individual_files" "$menu_label")
        else
            file_list=$(printf '%s\n%s' "$individual_files" "$menu_label")
        fi

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected=$(echo "$file_list" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --scrollbar='█' \
                --cycle \
                --preview-border=line \
                --header-border=line \
                --header-label=" Pacnew/Pacsave Manager " \
                --header-label-pos=0:bottom \
                --preview '

                    echo
                    selection="{}"

                    if [[ "$selection" == "← Menu" || "$selection" == "← Exit" ]]; then
                        echo -e "${BOLD}${CYAN}Return to Menu${RESET}"
                        echo
                        echo "Go back to the main SPM menu."
                        exit 0
                    fi

                    if [[ "$selection" == "[BULK] Delete All Pacnew"* ]]; then
                        echo -e "${BOLD}${CYAN}Bulk Action: Delete All Pacnew${RESET}"
                        echo
                        echo -e "${BOLD}${YELLOW}This will delete all .pacnew files,${RESET}"
                        echo -e "${BOLD}${YELLOW}keeping your current configurations.${RESET}"
                        echo
                        echo "Use this when you want to keep your existing configs"
                        echo "and discard the new package defaults."
                        echo
                        echo -e "${BOLD}Files that will be deleted:${RESET}"
                        sudo find /etc -name "*.pacnew" 2>/dev/null | head -20
                        exit 0
                    fi

                    if [[ "$selection" == "[BULK] Apply All Pacnew"* ]]; then
                        echo -e "${BOLD}${CYAN}Bulk Action: Apply All Pacnew${RESET}"
                        echo
                        echo -e "${BOLD}${YELLOW}This will replace all current configs${RESET}"
                        echo -e "${BOLD}${YELLOW}with their .pacnew versions.${RESET}"
                        echo
                        echo -e "${BOLD}WARNING:${RESET} Your current configurations will be overwritten!"
                        echo
                        echo -e "${BOLD}Files that will be replaced:${RESET}"
                        sudo find /etc -name "*.pacnew" 2>/dev/null | sed "s/.pacnew$//" | head -20
                        exit 0
                    fi

                    if [[ "$selection" == "[BULK] Delete All Pacsave"* ]]; then
                        echo -e "${BOLD}${CYAN}Bulk Action: Delete All Pacsave${RESET}"
                        echo
                        echo -e "${BOLD}${GREEN}This will delete all .pacsave backup files.${RESET}"
                        echo
                        echo "Use this to clean up old configuration backups"
                        echo "that were preserved when packages were removed."
                        echo
                        echo -e "${BOLD}Files that will be deleted:${RESET}"
                        sudo find /etc -name "*.pacsave" 2>/dev/null | head -20
                        exit 0
                    fi

                    file=$(echo "$selection" | sed "s/^\[PAC[A-Z]*\] //")

                    if [[ "$file" == *.pacnew ]]; then
                        original="${file%.pacnew}"
                        echo -e "${BOLD}${CYAN}Pacnew File${RESET}"
                        echo
                        echo -e "${BOLD}Original:${RESET} $original"
                        echo -e "${BOLD}New:${RESET} $file"
                        echo
                        echo -e "${BOLD}${YELLOW}A new version of this config was installed.${RESET}"
                        echo "Review the differences and decide which to keep."
                    else
                        original="${file%.pacsave}"
                        echo -e "${BOLD}${CYAN}Pacsave File${RESET}"
                        echo
                        echo -e "${BOLD}Current:${RESET} $original"
                        echo -e "${BOLD}Backup:${RESET} $file"
                        echo
                        echo -e "${BOLD}${GREEN}Your config was preserved during package removal.${RESET}"
                        echo "The backup contains your old configuration."
                    fi

                    echo
                    echo -e "${BOLD}=== DIFFERENCES ===${RESET}"
                    echo

                    if [[ -f "$original" && -f "$file" ]]; then
                        if command -v delta > /dev/null; then
                            delta --paging=never --line-numbers "$original" "$file" 2>/dev/null || echo "Cannot show diff"
                        elif command -v git > /dev/null; then
                            git diff --no-index --color=always "$original" "$file" 2>/dev/null || echo "Files are identical or cannot show diff"
                        else
                            diff --color=always -u "$original" "$file" 2>/dev/null || echo "Files are identical or cannot show diff"
                        fi
                    elif [[ ! -f "$original" ]]; then
                        echo "Original file does not exist."
                        echo
                        echo -e "${BOLD}New file contents:${RESET}"
                        head -50 "$file" 2>/dev/null
                    else
                        echo "Cannot compare files."
                    fi
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --header="$(get_spm_header)" \
                --footer="$footer_text" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi

            break
        done

        if [[ "$selected" == "← Menu" || "$selected" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

        if [[ "$selected" == "[BULK] Delete All Pacnew"* ]]; then
            clear_screen
            echo "Bulk Action: Delete All Pacnew Files"
            echo "====================================="
            echo
            local pacnew_files=$(sudo find /etc -name "*.pacnew" 2>/dev/null)
            echo "The following files will be deleted:"
            echo "$pacnew_files"
            echo
            local confirm
            read -p "Delete all .pacnew files? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "$pacnew_files" | while read -r f; do
                    sudo rm -v "$f"
                done
                echo
                echo "All .pacnew files deleted."
            else
                echo "Operation cancelled."
            fi
            sleep 2
            continue
        fi

        if [[ "$selected" == "[BULK] Apply All Pacnew"* ]]; then
            clear_screen
            echo "Bulk Action: Apply All Pacnew Files"
            echo "===================================="
            echo
            local pacnew_files=$(sudo find /etc -name "*.pacnew" 2>/dev/null)
            echo "The following configs will be REPLACED with new versions:"
            echo "$pacnew_files" | sed 's/.pacnew$//'
            echo
            echo "WARNING: Your current configurations will be overwritten!"
            echo
            local confirm
            read -p "Apply all .pacnew files? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "$pacnew_files" | while read -r f; do
                    local orig="${f%.pacnew}"
                    sudo mv -v "$f" "$orig"
                done
                echo
                echo "All .pacnew files applied."
            else
                echo "Operation cancelled."
            fi
            sleep 2
            continue
        fi

        if [[ "$selected" == "[BULK] Delete All Pacsave"* ]]; then
            clear_screen
            echo "Bulk Action: Delete All Pacsave Files"
            echo "======================================"
            echo
            local pacsave_files=$(sudo find /etc -name "*.pacsave" 2>/dev/null)
            echo "The following backup files will be deleted:"
            echo "$pacsave_files"
            echo
            local confirm
            read -p "Delete all .pacsave files? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "$pacsave_files" | while read -r f; do
                    sudo rm -v "$f"
                done
                echo
                echo "All .pacsave files deleted."
            else
                echo "Operation cancelled."
            fi
            sleep 2
            continue
        fi

        local file=$(echo "$selected" | sed 's/^\[PAC[A-Z]*\] //')
        local original
        local file_type

        if [[ "$file" == *.pacnew ]]; then
            original="${file%.pacnew}"
            file_type="pacnew"
        else
            original="${file%.pacsave}"
            file_type="pacsave"
        fi

        clear_screen


        if [[ "$file_type" == "pacnew" ]]; then
            echo "${BOLD}${CYAN}Pacnew File: $original${RESET}"
            echo
            echo "A package update provided a new default version of this config file."
            echo "Your current config was left untouched, and the new default was saved as:"
            echo "  ${YELLOW}$file${RESET}"
            echo
            echo "${BOLD}YOUR config:${RESET}     $original"
            echo "${BOLD}PACKAGE config:${RESET}  $file"
        else
            echo "${BOLD}${CYAN}Pacsave File: $original${RESET}"
            echo
            echo "A package was removed and your custom config was backed up as:"
            echo "  ${YELLOW}$file${RESET}"
            echo
            echo "${BOLD}CURRENT file:${RESET}  $original"
            echo "${BOLD}YOUR backup:${RESET}   $file"
        fi

        echo
        echo "${BOLD}=== DIFFERENCES ===${RESET}"
        echo

        if [[ -f "$original" && -f "$file" ]]; then
            if command -v delta > /dev/null; then
                delta --paging=always "$original" "$file"
            elif command -v git > /dev/null; then
                git diff --no-index --color=always "$original" "$file" | less -R
            else
                diff --color=always -u "$original" "$file" | less -R
            fi
        elif [[ ! -f "$original" ]]; then
            echo "Original file does not exist."
            echo
            less "$file"
        fi

        echo
        if [[ "$file_type" == "pacnew" ]]; then
            echo "${BOLD}What do you want to do?${RESET}"
            echo
            echo "  ${BOLD}${GREEN}1) Keep YOUR config${RESET}  - Discard the new package default"
            echo "     Deletes ${file##*/}, no changes to your config"
            echo
            echo "  ${BOLD}${YELLOW}2) Use PACKAGE config${RESET}  - Replace your config with the new default"
            echo "     Overwrites $original with the package version"
            echo
            echo "  ${BOLD}${CYAN}3) Merge manually${RESET}  - Open both files side-by-side in a diff editor"
            echo "     Lets you pick and choose changes from each file"
            echo
            echo "  ${BOLD}4) Skip${RESET}  - Do nothing for now"
        else
            echo "${BOLD}What do you want to do?${RESET}"
            echo
            echo "  ${BOLD}${GREEN}1) Keep current file${RESET}  - Delete the old backup"
            echo "     Deletes ${file##*/}"
            echo
            echo "  ${BOLD}${YELLOW}2) Restore YOUR backup${RESET}  - Replace current file with your saved config"
            echo "     Overwrites $original with your backup"
            echo
            echo "  ${BOLD}${CYAN}3) Merge manually${RESET}  - Open both files side-by-side in a diff editor"
            echo "     Lets you pick and choose changes from each file"
            echo
            echo "  ${BOLD}4) Skip${RESET}  - Do nothing for now"
        fi
        echo

        local choice
        read -p "Choice [1-4]: " choice

        case $choice in
            1)
                sudo rm "$file"
                if [[ "$file_type" == "pacnew" ]]; then
                    echo "${GREEN}Kept your config.${RESET} Deleted ${file##*/}"
                else
                    echo "${GREEN}Kept current file.${RESET} Deleted backup ${file##*/}"
                fi
                ;;
            2)
                sudo mv "$file" "$original"
                if [[ "$file_type" == "pacnew" ]]; then
                    echo "${YELLOW}Replaced your config with the package default.${RESET}"
                else
                    echo "${YELLOW}Restored your backup to $original${RESET}"
                fi
                ;;
            3)
                if command -v nvim > /dev/null; then
                    sudo nvim -d "$original" "$file"
                elif command -v vim > /dev/null; then
                    sudo vimdiff "$original" "$file"
                else
                    echo "No diff editor available (nvim or vim required)."
                    sleep 2
                fi
                if [[ -f "$file" ]]; then
                    echo
                    echo "The .$file_type file still exists. You can clean it up next time or select this file again."
                fi
                ;;
            4|*)
                echo "Skipped."
                ;;
        esac

        echo
        if [[ $CLI_MODE -eq 1 ]]; then
            read -p "Press any key to continue or Ctrl+C to exit... " -n 1 -s -r
            echo
        else
            read -p "Press any key to continue... " -n 1 -s -r
            echo
        fi
    done
}

hook_manager() {
    local user_hooks_dir="/etc/pacman.d/hooks"
    local system_hooks_dir="/usr/share/libalpm/hooks"

    while true; do
        clear

        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local menu_label
        local footer_text
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
            footer_text="Select a hook to manage | Enter to select | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            footer_text="Select a hook to manage | Enter to select | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi

        local hook_list=""

        hook_list="[+] Create New Hook"

        if [[ -d "$user_hooks_dir" ]]; then
            local user_hooks=$(find "$user_hooks_dir" -maxdepth 1 -type f \( -name "*.hook" -o -name "*.hook.disabled" \) 2>/dev/null | sort)
            if [[ -n "$user_hooks" ]]; then
                while IFS= read -r hook; do
                    local name=$(basename "$hook")
                    if [[ "$name" == *.disabled ]]; then
                        hook_list=$(printf '%s\n%s' "$hook_list" "[USER] [DISABLED] $name")
                    else
                        hook_list=$(printf '%s\n%s' "$hook_list" "[USER] [ENABLED] $name")
                    fi
                done <<< "$user_hooks"
            fi
        fi

        if [[ -d "$system_hooks_dir" ]]; then
            local system_hooks=$(find "$system_hooks_dir" -maxdepth 1 -type f -name "*.hook" 2>/dev/null | sort)
            if [[ -n "$system_hooks" ]]; then
                while IFS= read -r hook; do
                    local name=$(basename "$hook")
                    hook_list=$(printf '%s\n%s' "$hook_list" "[SYSTEM] $name")
                done <<< "$system_hooks"
            fi
        fi

        hook_list=$(printf '%s\n%s' "$hook_list" "$menu_label")

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected=$(echo "$hook_list" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --scrollbar='█' \
                --cycle \
                --preview-border=line \
                --header-border=line \
                --header-label=" Hook Manager " \
                --header-label-pos=0:bottom \
                --preview '

                    echo
                    case {} in
                        "← Menu"|"← Exit")
                            echo -e "${BOLD}${CYAN}Return to Menu${RESET}"
                            echo
                            echo "Go back to the main SPM menu."
                            ;;
                        "[+] Create New Hook")
                            echo -e "${BOLD}${CYAN}Create New Hook${RESET}"
                            echo
                            echo "Create a new ALPM hook in /etc/pacman.d/hooks/"
                            echo
                            echo -e "${BOLD}Hook Structure:${RESET}"
                            echo "[Trigger]"
                            echo "Operation = Install|Upgrade|Remove"
                            echo "Type = Package|Path|File"
                            echo "Target = <package-name-or-path>"
                            echo
                            echo "[Action]"
                            echo "When = PreTransaction|PostTransaction"
                            echo "Exec = /path/to/script"
                            ;;
                        "[USER] [DISABLED]"*)
                            name=$(echo {} | sed "s/\[USER\] \[DISABLED\] //")
                            echo -e "${BOLD}${YELLOW}[USER] [DISABLED]${RESET}"
                            echo -e "${BOLD}Location:${RESET} /etc/pacman.d/hooks/$name"
                            echo -e "${BOLD}Editable:${RESET} Yes"
                            echo
                            echo -e "${BOLD}=== HOOK CONTENT ===${RESET}"
                            echo
                            cat "/etc/pacman.d/hooks/$name" 2>/dev/null
                            ;;
                        "[USER] [ENABLED]"*)
                            name=$(echo {} | sed "s/\[USER\] \[ENABLED\] //")
                            echo -e "${BOLD}${GREEN}[USER] [ENABLED]${RESET}"
                            echo -e "${BOLD}Location:${RESET} /etc/pacman.d/hooks/$name"
                            echo -e "${BOLD}Editable:${RESET} Yes"
                            echo
                            echo -e "${BOLD}=== HOOK CONTENT ===${RESET}"
                            echo
                            cat "/etc/pacman.d/hooks/$name" 2>/dev/null
                            ;;
                        "[SYSTEM]"*)
                            name=$(echo {} | sed "s/\[SYSTEM\] //")
                            echo -e "${BOLD}${CYAN}[SYSTEM]${RESET}"
                            echo -e "${BOLD}Location:${RESET} /usr/share/libalpm/hooks/$name"
                            echo -e "${BOLD}Editable:${RESET} No (package-provided)"
                            echo
                            echo -e "${BOLD}=== HOOK CONTENT ===${RESET}"
                            echo
                            cat "/usr/share/libalpm/hooks/$name" 2>/dev/null
                            ;;
                    esac
                ' \
                --preview-window="right:${preview_width}%:wrap" \
                --header="$(get_spm_header)" \
                --footer="$footer_text" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi

            break
        done

        if [[ "$selected" == "← Menu" || "$selected" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
        fi

        if [[ "$selected" == "[+] Create New Hook" ]]; then
            clear_screen
            echo "Create New Hook"
            echo "==============="
            echo
            echo "Hooks will be created in: $user_hooks_dir/"
            echo

            local hook_name
            read -p "Enter hook name (without .hook extension): " hook_name

            if [[ -z "$hook_name" ]]; then
                echo "No name provided. Cancelled."
                sleep 1
                continue
            fi

            local hook_path="$user_hooks_dir/${hook_name}.hook"

            if [[ -f "$hook_path" ]]; then
                echo "Hook already exists: $hook_path"
                sleep 2
                continue
            fi

            sudo mkdir -p "$user_hooks_dir"

            local template="[Trigger]
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = ${hook_name}
When = PostTransaction
Exec = /bin/true
"
            echo "$template" | sudo tee "$hook_path" > /dev/null

            echo "Created hook template: $hook_path"
            echo "Opening in editor..."
            sleep 1

            if command -v nvim > /dev/null; then
                sudo nvim "$hook_path"
            elif command -v vim > /dev/null; then
                sudo vim "$hook_path"
            elif command -v nano > /dev/null; then
                sudo nano "$hook_path"
            else
                echo "No editor available."
                sleep 2
            fi
            continue
        fi

        local hook_file
        local hook_name
        local is_user_hook=false
        local is_disabled=false

        if [[ "$selected" == "[USER]"* ]]; then
            is_user_hook=true
            if [[ "$selected" == *"[DISABLED]"* ]]; then
                is_disabled=true
                hook_name=$(echo "$selected" | sed 's/\[USER\] \[DISABLED\] //')
            else
                hook_name=$(echo "$selected" | sed 's/\[USER\] \[ENABLED\] //')
            fi
            hook_file="$user_hooks_dir/$hook_name"
        else
            hook_name=$(echo "$selected" | sed 's/\[SYSTEM\] //')
            hook_file="$system_hooks_dir/$hook_name"
        fi

        clear_screen
        echo "Hook: $hook_name"
        echo "Location: $hook_file"
        echo

        if [[ "$is_user_hook" == true ]]; then
            echo "Actions:"
            echo "1) View hook content"
            echo "2) Edit hook"
            echo "3) Delete hook"
            if [[ "$is_disabled" == true ]]; then
                echo "4) Enable hook"
            else
                echo "4) Disable hook"
            fi
            echo "5) Back"

            local action
            read -p "Choice [1-5]: " action

            case $action in
                1)
                    clear_screen
                    echo "=== $hook_name ==="
                    echo
                    cat "$hook_file"
                    echo
                    read -p "Press any key to continue... " -n 1 -s -r
                    echo
                    ;;
                2)
                    if command -v nvim > /dev/null; then
                        sudo nvim "$hook_file"
                    elif command -v vim > /dev/null; then
                        sudo vim "$hook_file"
                    elif command -v nano > /dev/null; then
                        sudo nano "$hook_file"
                    else
                        echo "No editor available."
                        sleep 2
                    fi
                    ;;
                3)
                    local confirm
                    read -p "Delete $hook_name? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        sudo rm "$hook_file"
                        echo "Hook deleted."
                        sleep 1
                    else
                        echo "Operation cancelled."
                        sleep 1
                    fi
                    ;;
                4)
                    if [[ "$is_disabled" == true ]]; then
                        local enabled_name="${hook_name%.disabled}"
                        sudo mv "$hook_file" "$user_hooks_dir/$enabled_name"
                        echo "Hook enabled: $enabled_name"
                    else
                        sudo mv "$hook_file" "${hook_file}.disabled"
                        echo "Hook disabled: ${hook_name}.disabled"
                    fi
                    sleep 1
                    ;;
                5|*)
                    continue
                    ;;
            esac
        else
            echo "This is a system-provided hook (read-only)."
            echo
            echo "Actions:"
            echo "1) View hook content"
            echo "2) Copy to user hooks for customization"
            echo "3) Back"

            local action
            read -p "Choice [1-3]: " action

            case $action in
                1)
                    clear_screen
                    echo "=== $hook_name ==="
                    echo
                    cat "$hook_file"
                    echo
                    read -p "Press any key to continue... " -n 1 -s -r
                    echo
                    ;;
                2)
                    sudo mkdir -p "$user_hooks_dir"
                    sudo cp "$hook_file" "$user_hooks_dir/"
                    echo "Copied to: $user_hooks_dir/$hook_name"
                    echo "You can now edit this copy."
                    sleep 2
                    ;;
                3|*)
                    continue
                    ;;
            esac
        fi
    done
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
        "← Menu"|"← Exit") echo "Return to the main SPM menu.";;
        *) echo "No description available.";;
    esac
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

    local _edit_tmp
    _edit_tmp=$(mktemp /tmp/spm_pacman_edit.XXXXXX)
    (
        trap 'exit 130' INT
        read -e -i "$current_value" -p "Enter new value or press Enter to keep current: " new_value
        echo "$new_value" > "$_edit_tmp"
    )
    if [[ $? -eq 130 ]]; then
        echo
        echo "Operation cancelled."
        rm -f "$_edit_tmp"
        sleep 1
        return
    fi
    new_value=$(cat "$_edit_tmp" 2>/dev/null)
    rm -f "$_edit_tmp"

    if [[ -n "$new_value" && "$new_value" != "$current_value" ]]; then
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
    confirm=$(spm_read_input "Do you want to $new_status $option? [y/N] ") || {
        echo
        echo "Operation cancelled."
        sleep 1
        return
    }

    if [[ $confirm =~ ^[Yy]$ ]]; then
        if [[ "$new_status" == "enable" ]]; then
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
        if [[ $? -eq 0 ]]; then
            echo "$repo repository disabled successfully."
        else
            echo "Failed to disable $repo repository. Check sudo privileges."
        fi
    elif grep -q "^#\[$repo\]" /etc/pacman.conf; then
        echo "Enabling repository: $repo"
        sudo sed -i "/^#\[$repo\]/,/^$/s/^#//g" /etc/pacman.conf
        if [[ $? -eq 0 ]]; then
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

    if [[ -z "$options" ]]; then
        echo "No repositories found in pacman.conf"
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi

    local selected_repos=$(echo -e "$options" | fzf --reverse --multi \
        --style=full:line \
        --no-highlight-line \
        --scrollbar='█' \
        --preview-border=line \
        --border-label=" Manage Repositories " \
        --header="Select repositories to toggle | Tab to multi-select | Enter to confirm | Ctrl+C to return" \
        --bind 'ctrl-c:abort' \
        --bind 'resize:refresh-preview' \
        --ansi \
        | sed 's/^\[.*\] *//')

    if [[ -n "$selected_repos" ]]; then
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

    repo_name=$(spm_read_input "Enter the name of the new repository: ") || {
        echo
        echo "Operation cancelled."
        sleep 1
        return
    }

    if [[ -z "$repo_name" ]]; then
        echo "Repository name cannot be empty."
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi

    if grep -q "^\[$repo_name\]" /etc/pacman.conf || grep -q "^#\[$repo_name\]" /etc/pacman.conf; then
        echo "Repository '$repo_name' already exists in pacman.conf"
        read -p "Press any key to continue... " -n 1 -s -r
        return
    fi

    server_url=$(spm_read_input "Enter the server URL for the repository: ") || {
        echo
        echo "Operation cancelled."
        sleep 1
        return
    }

    if [[ -z "$server_url" ]]; then
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

    if command -v nvim > /dev/null; then
        sudo nvim /etc/pacman.conf
    elif command -v vim > /dev/null; then
        sudo vim /etc/pacman.conf
    elif command -v vi > /dev/null; then
        sudo vi /etc/pacman.conf
    elif command -v emacs > /dev/null; then
        sudo emacs /etc/pacman.conf
    elif command -v nano > /dev/null; then
        sudo nano /etc/pacman.conf
    elif command -v micro > /dev/null; then
        sudo micro /etc/pacman.conf
    else
        echo "No suitable editor found. Please manually edit /etc/pacman.conf."
        read -p "Press any key to continue... " -n 1 -s -r
        return 1
    fi

    echo "Editing complete."
}

pacman_config_menu() {
    while true; do
        clear

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
        )

        local menu_label
        local footer_text
        if [[ $CLI_MODE -eq 1 ]]; then
            menu_label="← Exit"
            footer_text="Select a configuration option | Enter to select | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview"
        else
            menu_label="← Menu"
            footer_text="Select a configuration option | Enter to select | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview"
        fi
        options+=("$menu_label")

        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        export -f get_option_description

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected_option=$(printf '%s\n' "${options[@]}" |
                fzf --reverse \
                    --cycle \
                    --style=full:line \
                    --no-highlight-line \
                    --preview-border=line \
                    --header-label=" Pacman Configuration " \
                    --header-label-pos=0:bottom \
                    --header-border=line \
                    --preview '

                        echo
                        opt=$(echo {} | sed "s/^\[[^]]*\] //")

                        echo -e "${BOLD}${CYAN}Pacman Configuration${RESET}"
                        echo

                        current_val=""
                        if grep -q "^$opt" /etc/pacman.conf 2>/dev/null; then
                            current_val=$(grep "^$opt" /etc/pacman.conf | sed "s/.*=//; s/^[[:space:]]*//" | tail -n 1)
                            current_val="${current_val:-Enabled - no value}"
                            echo -e "${BOLD}${GREEN}Status: ENABLED${RESET}"
                        elif grep -q "^#$opt" /etc/pacman.conf 2>/dev/null; then
                            current_val="Disabled - commented out"
                            echo -e "${BOLD}${YELLOW}Status: DISABLED${RESET}"
                        else
                            current_val="Not set"
                            echo -e "${BOLD}Status: NOT SET${RESET}"
                        fi

                        echo -e "${BOLD}Option:${RESET} $opt"
                        echo -e "${BOLD}Current Value:${RESET} $current_val"
                        echo
                        echo -e "${BOLD}Description:${RESET}"
                        get_option_description "$opt"
                        echo
                        echo "Pacman Configuration Summary:"
                        echo "-----------------------------"
                        awk "/^\[.*\]/ { print \"\n\" \$0 \":\"; next } /^#/ { next } /^\$/ { next } { gsub(/^[ \t]+|[ \t]+\$/, \"\"); if (\$0 != \"\") print \"  \" \$0 }" /etc/pacman.conf
                    ' \
                    --preview-window="right:${preview_width}%:wrap" \
                    --header="$(get_spm_header)" \
                    --footer="$footer_text" \
                    --footer-border=line \
                    --bind 'ctrl-c:abort' \
                    --bind 'resize:refresh-preview' \
                    "${FZF_RESIZE_BINDS[@]}" \
                    --height=100% \
                    --color=header:-1,footer:$FZF_FOOTER_COLOR \
                    --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    if [[ $CLI_MODE -eq 1 ]]; then
                        clear
                        echo "Exiting SPM - Simple Package Manager. Goodbye!"
                    fi
                    return
                fi
            fi

            break
        done

        if [[ "$selected_option" == "← Menu" || "$selected_option" == "← Exit" ]]; then
            if [[ $CLI_MODE -eq 1 ]]; then
                clear
                echo "Exiting SPM - Simple Package Manager. Goodbye!"
            fi
            return
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
        esac
    done
}

system_tools_menu() {
    while true; do
        local preview_width=$(get_preview_width)

        echo 0 > "$RESIZE_FLAG_FILE"

        local options=(
            "Dependencies"
            "Hook Manager"
            "Pacnew/Pacsave Manager"
            "Pacman Configuration"
            "← Menu"
        )

        local spm_header
        spm_header=$(get_spm_header)

        clear

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            local selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
                --preview-border=line \
                --header-border=line \
                --header-label=" System Tools " \
                --header-label-pos=0:bottom \
                --preview "
                    echo
                    case {} in
                        'Dependencies'*)
                            printf '\033[1m\033[36mDependencies\033[0m\n'
                            echo
                            echo '• Explore Dependencies - Dependency tree for any package'
                            echo '• High-Impact Removals - Packages that free the most space'
                            echo '• Browse Explicit - Review what you manually installed'
                            ;;
                        'Hook Manager'*)
                            printf '\033[1m\033[36mHook Manager\033[0m\n'
                            echo
                            echo '• Create, edit, enable/disable user hooks'
                            echo '• View system hooks (read-only)'
                            echo '• Hooks in /etc/pacman.d/hooks/ and /usr/share/libalpm/hooks/'
                            ;;
                        'Pacnew/Pacsave Manager'*)
                            printf '\033[1m\033[36mPacnew/Pacsave Manager\033[0m\n'
                            echo
                            echo '• View diffs between current and new config files'
                            echo '• Apply, delete, or merge individual files'
                            echo '• Bulk apply or delete all pacnew/pacsave files'
                            ;;
                        'Pacman Configuration'*)
                            printf '\033[1m\033[36mPacman Configuration\033[0m\n'
                            echo
                            echo '• Edit options: ParallelDownloads, IgnorePkg, CacheDir, etc.'
                            echo '• Toggle settings: Color, CheckSpace, ILoveCandy, etc.'
                            echo '• Add and manage repositories'
                            ;;
                        *)
                            echo 'Return to main menu'
                            ;;
                    esac
                " \
                --preview-window="right:${preview_width}%:wrap" \
                --header="${spm_header}" \
                --footer="Select an option | Enter to confirm | Ctrl+C to return
Alt+[ increase preview | Alt+] decrease preview" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
                    continue
                else
                    return
                fi
            fi

            break
        done

        case "$selected_option" in
            "Dependencies") dependencies_menu ;;
            "Hook Manager") hook_manager ;;
            "Pacnew/Pacsave Manager") pacnew_pacsave_manager ;;
            "Pacman Configuration") pacman_config_menu ;;
            "← Menu") return ;;
        esac
    done
}

manager() {
    local options=(
        "Install Packages"
        "Remove Packages"
        "Update Packages"
        "Downgrade Packages"
        "Clean Orphans"
        "Clear Package Cache"
        "System Tools"
        "Exit"
    )
    local preview_width
    local selected_option
    local recent_updated recent_installed recent_removed
    recent_updated=$(mktemp /tmp/spm_recent_updated.XXXXXX)
    recent_installed=$(mktemp /tmp/spm_recent_installed.XXXXXX)
    recent_removed=$(mktemp /tmp/spm_recent_removed.XXXXXX)

    exit_script() {
        rm -f "$recent_updated" "$recent_installed" "$recent_removed"
        clear
        echo "Exiting SPM - Simple Package Manager. Goodbye!"
        exit 0
    }

    while true; do
        echo 0 > "$RESIZE_FLAG_FILE"

        tac /var/log/pacman.log 2>/dev/null | awk '
            /\[ALPM\] upgraded/ { gsub(/[()]/, "", $4); if (!up[$4]++) { print $4; if (++c >= 50) exit } }' > "$recent_updated"
        tac /var/log/pacman.log 2>/dev/null | awk '
            /\[ALPM\] installed/ { gsub(/[()]/, "", $4); if (!inst[$4]++) { print $4; if (++c >= 50) exit } }' > "$recent_installed"
        tac /var/log/pacman.log 2>/dev/null | awk '
            /\[ALPM\] removed/ { gsub(/[()]/, "", $4); if (!rem[$4]++) { print $4; if (++c >= 50) exit } }' > "$recent_removed"

        local spm_header
        spm_header=$(get_spm_header)
        preview_width=$(get_preview_width)

        clear

        while true; do
            preview_width=$(cat "$PREVIEW_WIDTH_FILE")

            selected_option=$(printf '%s\n' "${options[@]}" | fzf --reverse \
                --style=full:line \
                --no-highlight-line \
                --cycle \
                --no-input \
                --preview-border=line \
                --header-border=line \
                --header-label=" SPM Main Menu " \
                --header-label-pos=0:bottom \
                --preview "
                    n=\$(( (FZF_PREVIEW_LINES - 6) / 3 ))
                    [ \"\$n\" -lt 5 ] && n=5

                    echo
                    printf '\033[1m\033[32mRecently Updated:\033[0m\n'
                    head -n \$n '$recent_updated'
                    echo
                    printf '\033[1m\033[36mRecently Installed:\033[0m\n'
                    head -n \$n '$recent_installed'
                    echo
                    printf '\033[1m\033[31mRecently Removed:\033[0m\n'
                    head -n \$n '$recent_removed'
                " \
                --preview-window="right:${preview_width}%:wrap" \
                --header="${spm_header}" \
                --footer="Enter to select | Ctrl+C to exit
Alt+[ increase preview | Alt+] decrease preview" \
                --footer-border=line \
                --bind 'ctrl-c:abort' \
                --bind 'resize:refresh-preview' \
                "${FZF_RESIZE_BINDS[@]}" \
                --height=100% \
                --color=header:-1,footer:$FZF_FOOTER_COLOR \
                --ansi)

            if [[ -z "$selected_option" ]]; then
                if [[ $(cat "$RESIZE_FLAG_FILE" 2>/dev/null || echo "0") -eq 1 ]]; then
                    echo 0 > "$RESIZE_FLAG_FILE"
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
            "Downgrade Packages") downgrade ;;
            "Clean Orphans") orphan ;;
            "Clear Package Cache") clear_cache ;;
            "System Tools") system_tools_menu ;;
            "Exit") exit_script ;;
        esac
    done
}

[[ ! -f "$UPDATE_CACHE_FILE" ]] && echo "0" > "$UPDATE_CACHE_FILE"
[[ ! -f "$DETAILED_UPDATE_CACHE_FILE" ]] && echo "No updates available." > "$DETAILED_UPDATE_CACHE_FILE"

if [[ $# -eq 0 ]]; then
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
            shift
            downgrade "$*"
            exit 0
            ;;
        -c|cache)
            clear_cache
            exit 0
            ;;
        -p|pacnew)
            pacnew_pacsave_manager
            exit 0
            ;;
        -H|hooks)
            hook_manager
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Invalid option: $1."
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
fi