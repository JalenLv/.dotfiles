#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

syml-rc() {
    local source="$1"
    local target="$2"
    local name="$3"

    if [ -e "$target" ] || [ -L "$target" ]; then
        read -r -p "$target already exists. Do you want to back it up? [Y/n] " response
        if [[ "$response" =~ ^[Yy]$ || -z "$response" ]]; then
            backup_target="${target}_bak"
            mv "$target" "$backup_target"
            echo "Backed up existing $name config to $backup_target"
        else
            rm -rf "$target"
            echo "Removed existing $name config at $target"
        fi
    fi

    ln -s "$source" "$target"
    echo "Symlinked $name config from $source to $target"
}

# --- NEOVIM --- #

NVIM_CONF_SOURCE="$SCRIPT_DIR/nvim-conf"
NVIM_CONF_TARGET="$HOME/.config/nvim"
syml-rc "$NVIM_CONF_SOURCE" "$NVIM_CONF_TARGET" "Neovim"

# --- VIM --- #
VIMRC_SOURCE="$SCRIPT_DIR/.vimrc"
VIMRC_TARGET="$HOME/.vimrc"
syml-rc "$VIMRC_SOURCE" "$VIMRC_TARGET" "Vim"

# --- TMUX --- #
TMUX_CONF_SOURCE="$SCRIPT_DIR/.tmux.conf"
TMUX_CONF_TARGET="$HOME/.tmux.conf"
syml-rc "$TMUX_CONF_SOURCE" "$TMUX_CONF_TARGET" "Tmux"

# --- LATEXMK --- #
LATEXMKRC_SOURCE="$SCRIPT_DIR/.latexmkrc"
LATEXMKRC_TARGET="$HOME/.latexmkrc"
syml-rc "$LATEXMKRC_SOURCE" "$LATEXMKRC_TARGET" "Latexmk"

# --- IDEAVIM --- #
IDEAVIMRC_SOURCE="$SCRIPT_DIR/.ideavimrc"
IDEAVIMRC_TARGET="$HOME/.ideavimrc"
syml-rc "$IDEAVIMRC_SOURCE" "$IDEAVIMRC_TARGET" "IdeaVim"

echo "All configurations have been set up successfully!"