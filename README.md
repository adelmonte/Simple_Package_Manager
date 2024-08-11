# SPM - Simple Package Manager

![Description of the GIF](spm.gif)

SPM is a Simple Package Manager for Arch-based Linux distributions.  

It provides an intuitive fzf interface for common package management tasks using `yay` and `pacman`.

## Features

- Interactive menu-driven interface
- fzf Package installation and removal
- Dependency exploration and analysis
- System update
- Orphaned package cleanup
- Package downgrading
- Cache clearing
- Package count, pacman and yay cache monitor, and optional "Available Updates" counter.
  
## CAUTION!
- (Optional) shell sources will hijack `install` command
- Updates are auto-yes, no-confirm and include flatpak updates
- Clean Package Cache will also auto select `y` for all options after starting

## Prerequisites

SPM requires the following dependencies:

- `fzf`: For the interactive interface
- `yay`: For AUR package management
- `fish`: For optional "source" integration in config.fish, see below.
- `flatpak`: Possible?

## Installation>

1. Clone this repository ```git clone https://github.com/adelmonte/Simple_Package_Manager```
2. Change directory ```cd Simple_Package_Manager```
3. Install ```makepkg -si```

After running the following commands, you can use SPM commands (install, remove, orphan) by typing (install *, remove *, orphan *) in your terminal."  

- For Bash users:
`echo 'source /usr/bin/spm' >> ~/.bashrc`

- For Fish users:
`echo 'source /usr/share/fish/vendor_functions.d/spm.fish' >> ~/.config/fish/config.fish`

To enable (optional) available update checking:  
`sudo systemctl enable --now spm_updates.timer
&& sudo systemctl enable --now spm_updates.service`  

The systemd timer is defaulted to run every 5 minutes and stores it's value in /var/cache/update-cache.txt  

The update service can be manually triggered from shell with `update-cache.sh `

## Usage

### Interactive Mode

To launch SPM in interactive mode, simply run:

```
spm
```

This will present you with a menu of available options.

### Command-line Options

SPM also supports command-line options for quick access to specific functions:

- `-u *` or `update`: Update packages
- `-i *` or `install`: Install packages
- `-r *` or `remove`: Remove packages
- `-o*` or `orphan`: Clean orphaned packages
- `-h` or `--help`: Display help message

Example usage:

```
spm -i adb    # Find adb package through fzf installer
spm -r adb    # Remove adb package through fzf remover
spm -u        # Updates entire system

install adb   # Also finds adb package to install
remove adb    # Also finds adb package to remove
update        # Updates entire system
```
## License

This project is open source and available under the [GPL v3.0 License](LICENSE).
