#!/usr/bin/env bash
# This script symlinks .vimrc to the home directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIMRC_SOURCE="$SCRIPT_DIR/.vimrc"
VIMRC_TARGET="$HOME/.vimrc"

# If the target already exists, ask for confirmation to back it up
# Defaults to yes if the user just presses enter
if [ -e "$VIMRC_TARGET" ] || [ -L "$VIMRC_TARGET" ]; then
    read -r -p "$VIMRC_TARGET already exists. Do you want to back it up? [Y/n] "
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        BACKUP_TARGET="$VIMRC_TARGET.bak"
        mv "$VIMRC_TARGET" "$BACKUP_TARGET"
        echo "Backed up existing .vimrc to $BACKUP_TARGET"
    else
        echo "Aborting. .vimrc was not modified."
        exit 0
    fi
fi

ln -s "$VIMRC_SOURCE" "$VIMRC_TARGET"
echo "Symlinked $VIMRC_SOURCE to $VIMRC_TARGET"

