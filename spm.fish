#!/usr/bin/env fish

# Path to the original Bash script
set -g bash_script_path "/usr/bin/spm"

# Full path to bash
set -g bash_path (which bash)

function update
    $bash_path -c "source $bash_script_path && update"
end

function install
    $bash_path -c "source $bash_script_path && install $argv"
end

function remove
    $bash_path -c "source $bash_script_path && remove $argv"
end

function orphan
    $bash_path -c "source $bash_script_path && orphan"
end

function downgrade
    $bash_path -c "source $bash_script_path && downgrade $argv"
end

# Main function to handle command-line arguments
function spm
    if test (count $argv) -eq 0
        $bash_path -c "source $bash_script_path && manager"
    else
        switch $argv[1]
            case -u
                update
            case -i
                install $argv[2..-1]
            case -r
                remove $argv[2..-1]
            case -o
                orphan
            case -h --help
                show_help
            case '*'
                echo "Unknown option: $argv[1]"
                show_help
        end
    end
end