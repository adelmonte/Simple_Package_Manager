# SPM - Simple Package Manager

![Simple Package Manager Interface](spm.gif)

A lightweight, intuitive package manager interface for Arch-based Linux distributions that leverages the power of `fzf` to provide a seamless interactive experience for managing packages through `pacman` and `yay`.

## Features

### Elegant Interactive Interface
- **Dynamic FZF-powered menus** with real-time previews and adjustable preview windows
- **Multi-select functionality** for efficient batch operations
- **Context-aware information** showing package details, dependencies, and system status
- **Intuitive navigation** with keyboard shortcuts and visual feedback

### Comprehensive Package Management
- **Smart installation system**
  - Repository-prioritized package listing
  - Detailed package information previews
  - PKGBUILD preview for AUR packages
  - Multi-select for batch installation

- **Flexible removal options**
  - Multiple removal modes with different dependency handling
  - Preview installed files before removal
  - Configurable confirmation prompts

- **Versatile update workflows**
  - Quick updates with auto-confirmation
  - Detailed review mode for cautious updating
  - Selective update options (system, flatpak, AUR dev packages)

### Advanced Dependency Management
- **Orphaned package cleanup** with multiple handling options
- **Dependency exploration tools**
  - Interactive dependency browser
  - Package sorting by dependency count
  - Exclusive dependency analysis

### System Maintenance Utilities
- **Downgrade functionality**
  - Local cache searching
  - Arch Linux Archive (ALA) integration
  - Version preview and selection

- **Cache management**
  - Configurable cache clearing options
  - Space usage monitoring
  - Per-repository cache statistics

- **Pacman configuration interface**
  - Visual editor for pacman.conf
  - Repository enabling/disabling
  - Option toggling with explanations

## Installation

```bash
yay -S spm-arch
```

### Post-Installation Setup

#### Enable Update Monitoring **[Required]**
```bash
systemctl enable --now spm_updates.timer
```

#### Shell Integration for Direct Commands **[Optional]**
For Bash users:
```bash
echo 'source /usr/bin/spm' >> ~/.bashrc
```

For Fish users:
```bash
echo 'source /usr/share/fish/vendor_functions.d/spm.fish' >> ~/.config/fish/config.fish
```

## Usage

### Interactive Mode
Simply run:
```bash
spm
```

Navigate with arrow keys, select with Enter, and multi-select with Tab where applicable.

### Command Line Options

| Option | Standalone | Description |
|--------|------------|-------------|
| `-u`, `update` | `update` | Update system packages |
| `-i`, `install` | `install [pkg]` | Install specified packages |
| `-r`, `remove` | `remove [pkg]` | Remove specified packages |
| `-o`, `orphan` | `orphan` | Clean orphaned packages |
| `-d`, `downgrade` | `downgrade` | Downgrade packages |
| `-c`, `cache` | N/A | Clear package cache |
| `-h`, `--help` | N/A | Display help information |

**Note:** Standalone commands require shell integration.

### Tips and Shortcuts
- Use **Alt+[** and **Alt+]** to adjust preview window size
- Press **Tab** to multi-select packages
- Press **Ctrl+C** to return to previous menu or exit
- View system status in the header bar (packages, updates, cache sizes)

## Requirements
- `fzf` - For interactive interface functionality
- `yay` - For AUR package management
- `pacman` - Base package management (included in all Arch systems)

## License
This project is released under the [GPL v3.0 License](LICENSE).

## Notes on Update Service
The update monitoring service:
- Runs by default every 5 minutes
- Stores update information in `/var/cache/spm/update-cache.txt`
- Can be manually triggered with `spm_updates`
- Ensures package databases are synchronized before installations
