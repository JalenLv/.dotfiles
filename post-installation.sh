#!/usr/bin/env bash
# This script installs common packages.
set -euo pipefail

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

# Apt upgrade
echo "Upgrading existing packages..."
sudo apt upgrade -y

# Zsh and Oh My zsh
read -r -p "Do you want to install Zsh and Oh My Zsh? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    SHELL_NAME=$(basename "$SHELL")
    if [[ "$SHELL_NAME" != "zsh" ]]; then
        echo "Installing Zsh..."
        sudo apt install -y zsh
        chsh -s "$(which zsh)"
        echo "Please log out and log back in to start using Zsh as your default shell."
        exit 0
    fi
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Skipping Zsh and Oh My Zsh installation."
fi

# Miniconda
read -r -p "Do you want to install Miniconda? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Downloading Miniconda installer..."
    TMP=$(mktemp).sh
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

        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

        brew install neovim

        brew install node@24
        echo "export PATH="/home/linuxbrew/.linuxbrew/opt/node@24/bin:\$PATH"" >> "$SHELL_RC"

        export PATH="/home/linuxbrew/.linuxbrew/opt/node@24/bin:$PATH"
        export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
        corepack enable
        corepack prepare yarn@stable --activate

        brew install tree-sitter-cli

        source $HOME/miniconda3/etc/profile.d/conda.sh
        conda activate base
        pip install neovim

        sudo apt install -y python3-venv
    )
    echo "Neovim installation complete."
else
    echo "Skipping Neovim installation."
fi

# VSCode
read -r -p "Do you want to install Visual Studio Code? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Setting up MS VSCode repository..."
    sudo apt install -y gpg

    # Import Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f microsoft.gpg

    # Add VSCode repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

    echo "Installing Visual Studio Code..."
    sudo apt update
    sudo apt install -y code
else
    echo "Skipping Visual Studio Code installation."
fi

