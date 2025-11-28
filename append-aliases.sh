#!/usr/bin/env bash
# This script appends alias definitions in .aliases to the user's shell configuration file.
set -euo pipefail

# Determine the user's shell and corresponding configuration file
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
    bash)
        CONFIG_FILE="$HOME/.bashrc"
        ;;
    zsh)
        CONFIG_FILE="$HOME/.zshrc"
        ;;
    *)
        echo "Unsupported shell: $SHELL_NAME"
        exit 1
        ;;
esac

ALIASES_FILE="./.aliases"
if [ ! -f "$ALIASES_FILE" ]; then
    echo "Aliases file not found: $ALIASES_FILE"
    exit 1
fi
# Append aliases to the configuration file if not already present
ALIASES_PREFACE="# Aliases added by .dotfiles/append-aliases.sh"
if ! grep -qF "$ALIASES_PREFACE" "$CONFIG_FILE"; then
    {
        echo ""
        echo "$ALIASES_PREFACE"
        cat "$ALIASES_FILE"
        echo ""
    } >> "$CONFIG_FILE"
    echo "Aliases appended to $CONFIG_FILE"
else
    echo "Aliases already present in $CONFIG_FILE"
fi

