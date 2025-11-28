#!/usr/bin/env bash
# This script installs common packages.
set -euxo pipefail

# Check if apt is available
if ! command -v apt &> /dev/null; then
    echo "apt package manager not found. This script is intended for Debian-based systems."
    exit 1
fi

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install common packages
COMMON_PACKAGES=(
    git
    curl
    wget
    vim-gtk3
    htop
    build-essential
    unzip
    tar
    software-properties-common
)
echo "Installing common packages..."
sudo apt install -y "${COMMON_PACKAGES[@]}"

# Optional apt upgrade
read -r -p "Do you want to upgrade existing packages? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Upgrading existing packages..."
    sudo apt upgrade -y
else
    echo "Skipping package upgrade."
fi

# Miniconda
read -r -p "Do you want to install Miniconda? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Downloading Miniconda installer..."
    TMP=$(mktemp)
    curl -o $TMP https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh

    echo "Installing Miniconda at $HOME/miniconda3..."
    bash $TMP -b -p "$HOME/miniconda3"

    rm -f $TMP

    echo "Initializing Miniconda..."
    "$HOME/miniconda3/bin/conda" init $(basename "$SHELL")
else
    echo "Skipping Miniconda installation."
fi

# Homebrew
read -r -p "Do you want to install Homebrew? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Downloading Homebrew..."
    TMP=$(mktemp)
    curl -o $TMP https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

    echo "Installing Homebrew..."
    NONINTERACTIVE=1 bash $TMP

    rm -f $TMP

    echo "Running Homebrew post-instsallation steps..."
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            SHELL_RC="$HOME/.bashrc"
            ;;
        zsh)
            SHELL_RC="$HOME/.zshrc"
            ;;
        *)
            echo "Unsupported shell: $SHELL_NAME"
            exit 1
            ;;
    esac
    {
        echo ""
        echo "# Homebrew"
        echo "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
        echo "if type brew &>/dev/null; then"
        echo "    FPATH=\$(brew --prefix)/share/\$SHELL_NAME-completions:\$FPATH"
        echo "    autoload -Uz compinit"
        echo "    compinit"
        echo "fi"
        echo ""
    } >> "$SHELL_RC"
else
    echo "Skipping Homebrew installation."
fi

# Neovim from Homebrew
echo "Do you want to install Neovim from Homebrew?"
echo "This installs Node.js and tree-sitter-cli from Homebrew as dependencies."
read -r -p "This also installs neovim module in conda's base environment. [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Installing Neovim from Homebrew..."
    (
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        brew install neovim
        brew install node@24
        brew install tree-sitter-cli
        source $HOME/miniconda3/etc/profile.d/conda.sh
        conda activate base
        pip install neovim
    )
    echo "Neovim installation complete."
else
    echo "Skipping Neovim installation."
fi

