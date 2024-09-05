# SPM - Simple Package Manager

![Description of the GIF](spm.gif)

SPM is a Simple Package Manager for Arch-based Linux distributions.  

It provides an intuitive fzf interface for common package management tasks using `yay` and `pacman`.

## Features

- fzf menu-driven interface (with multi-select)
- System update
- Orphaned package cleanup
- Dependency exploration and analysis
- Package downgrading
- Cache clearing
- Package count, pacman and yay cache monitor, and available "Updates" counter.
  
## CAUTION!028592
- (Optional) shell sources will hijack `install` command
- Updates are auto-yes, no-confirm and include flatpak updates (user can edit script if they wish)
- Clean Package Cache will also auto select `y` for all options after confirmation
- Removal is -Rnsc

## Prerequisites

SPM requires the following dependencies:

- `fzf`: For the interactive interface
- `yay`: For AUR package management

## Installation

1. Clone this repository ```git clone https://github.com/adelmonte/Simple_Package_Manager```
2. Change directory ```cd Simple_Package_Manager```
3. Install ```makepkg -si```

Enable Optional Shell Sources for standalone arguments:  

- For Bash users:
`echo 'source /usr/bin/spm' >> ~/.bashrc`

- For Fish users:
`echo 'source /usr/share/fish/vendor_functions.d/spm.fish' >> ~/.config/fish/config.fish`

To enable (required) available update checking:  
```
systemctl enable --now spm_updates.timer  
```
Without the service, the install command will not sync package databases before install. See [Other](#other).  

The systemd timer is defaulted to run every 5 minutes and stores it's value in `/var/cache/spm/update-cache.txt`

The update service can be manually triggered from shell with `spm_updates`

## Usage

### Interactive Mode

To launch SPM in interactive mode, simply run:

```
spm
```

This will present you with a menu of available options.

### Command-line Options

SPM also supports command-line options for quick access to specific functions:

- `-u`   or `update`: Update packages
- `-i *` or `install`: Install packages
- `-r *` or `remove`: Remove packages
- `-o`   or `orphan`: Clean orphaned packages
- `-h`   or `--help`: Display help message

Example usage:

```
$ spm -i fzf	# Install packages
$ spm -r fzf    # Remove package
$ spm -u        # Updates entire system (alternative)
$ spm -o        # Clean orphaned packages (alternative)
$ spm -d        # Downgrade a package
$ spm -c        # Clear package cache

OR with the optional shell sources from the instructions above:

$ install fzf   # Also finds fzf package to install
$ remove fzf    # Also finds fzf package to remove
$ update        # Updates entire system
$ orphan        # Clean orphaned packages
$ downgrade     # Downgrade a package
```
## Other

If you don't wish to use the update service (which is convientient since the install function doesn't require a sudo password to sync package database) see the file: `optional-install-function-no-update-service-pacman_-Sy`

Generally speaking the functions (such as update including flatpak) and headers aren't difficult for a novice to edit to their liking.


## License

This project is open source and available under the [GPL v3.0 License](LICENSE).
