#!/usr/bin/env bash
# This script symlinks the neovim config files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_SOURCE="$SCRIPT_DIR/nvim-conf"
NVIM_CONFIG_TARGET="$HOME/.config/nvim"

# If the target already exists, ask for confirmation to back it up
# Defaults to yes if the user just presses enter
if [ -e "$NVIM_CONFIG_TARGET" ] || [ -L "$NVIM_CONFIG_TARGET" ]; then
    read -r -p "$NVIM_CONFIG_TARGET already exists. Do you want to back it up? [Y/n] "
    if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
        BACKUP_TARGET="${NVIM_CONFIG_TARGET}_bak"
        mv "$NVIM_CONFIG_TARGET" "$BACKUP_TARGET"
        echo "Backed up existing neovim config to $BACKUP_TARGET"
    else
        echo "Aborting. Neovim config not changed."
        exit 0
    fi
fi

ln -s "$NVIM_CONFIG_SOURCE" "$NVIM_CONFIG_TARGET"
echo "Symlinked neovim config from $NVIM_CONFIG_SOURCE to $NVIM_CONFIG_TARGET"

