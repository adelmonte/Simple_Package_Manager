# SPM - Simple Package Manager

![Simple Package Manager Interface](spm.gif)

A TUI wrapper for pacman and yay that makes package management visual and interactive.

## What It Does

SPM replaces command-line package management with an interactive interface. Instead of remembering pacman flags and typing package names, you browse, search, and select packages visually with real-time information previews.

### Why Use This?

- **Faster workflow** - Multi-select and batch operations beat typing package names repeatedly
- **Better decisions** - See package details, dependencies, and file lists before installing or removing
- **Less mistakes** - Visual confirmation and impact preview reduce accidental removals
- **Easier maintenance** - Find orphans, analyze dependencies, and manage cache without memorizing commands

## Key Features

**Cache intelligence** - Automatic background sync keeps package lists current for fast searchin

**Visual package browser** - Search and install from all repositories with live package information, descriptions, and dependencies displayed as you navigate

**Built-in downgrade** - Access Arch Linux Archive directly to roll back problematic updates without external tools

**Multiple removal strategies** - Choose between different dependency handling methods depending on what you're removing

**Dependency analysis** - See what depends on what, find orphaned packages, and understand removal impact before you commit

**Interactive configuration** - Edit pacman.conf options and manage repositories without opening a text editor

## Installation

```bash
yay -S spm-arch
```

## Usage

Interactive mode:
```bash
spm
```

Direct commands:
```bash
spm -i [package]    # Install
spm -r [package]    # Remove
spm -u              # Update
spm -o              # Clean orphans
spm -d [package]    # Downgrade
spm -c              # Manage cache
```

## Requirements

- fzf
- yay

## License

GPL-3.0-or-later
