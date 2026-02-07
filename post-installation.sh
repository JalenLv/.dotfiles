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

# Ubuntu or Debian?
os=$(grep '^ID=' /etc/os-release | cut -d= -f2- | tr -d '"')

# Install common packages
COMMON_PACKAGES=(
    git
    curl
    wget
    vim-gtk3
    htop
    build-essential
    cmake
    ninja-build
    pkg-config
    unzip
    tar
    tmux
)
if [[ "$os" == "ubuntu" ]]; then
    COMMON_PACKAGES+=(software-properties-common)
fi
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

# JetBrains Mono Nerd Font
read -r -p "Do you want to install JetBrains Mono Nerd Font? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Installing JetBrains Mono Nerd Font..."

    TMP=$(mktemp).zip
    URL=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep -i jetbrain | grep url | grep zip | cut -d : -f 2,3 | tr -d \")
    wget -O $TMP $(echo $URL)

    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    mkdir -p "$FONT_DIR"
    unzip -o $TMP -d "$FONT_DIR"
    rm -f $TMP

    echo "Updating font cache..."
    fc-cache -f -v
    sudo fc-cache -f -v

    echo "JetBrains Mono Nerd Font installation complete."
else
    echo "Skipping JetBrains Mono Nerd Font installation."
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
        {
            echo "# Node.js"
            echo "export PATH="/home/linuxbrew/.linuxbrew/opt/node@24/bin:\$PATH""
        } >> "$SHELL_RC"

        export PATH="/home/linuxbrew/.linuxbrew/opt/node@24/bin:$PATH"
        export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
        corepack enable
        corepack prepare yarn@stable --activate

        brew install tree-sitter-cli

        source $HOME/miniconda3/etc/profile.d/conda.sh
        conda activate base
        pip install neovim

        sudo apt install -y python3-venv
        # If using wayland ($WAYLAND_DISPLAY is set), install wl-clipboard
        # If using X11, install only xclip
        if [[ -n "${WAYLAND_DISPLAY-}" ]]; then
            sudo apt install -y wl-clipboard xclip
        else
            sudo apt install -y xclip
        fi
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

# Docker
read -r -p "Do you want to install Docker? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    # Remove old versions of Docker if they exist
    echo "Removing old versions of Docker if they exist..."
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

    echo "Setting up Docker repository..."
    # Add Docker's official GPG key:
    sudo apt install -y ca-certificates
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    if [[ "$os" == "ubuntu" ]]; then
        sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    elif [[ "$os" == "debian" ]]; then
        sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    else
        echo "Unsupported OS: $os"
        exit 1
    fi
    sudo apt update

    echo "Installing Docker..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Adding user $USER to docker group..."
    sudo groupadd docker || true
    sudo usermod -aG docker $USER
else
    echo "Skipping Docker installation."
fi

# NoMachine
read -r -p "Do you want to install NoMachine? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Installing NoMachine..."
    case "$(uname -m)" in
        x86_64)
            URL="https://www.nomachine.com/free/linux/64/deb"
            ;;
        aarch64)
            URL="https://www.nomachine.com/free/arm/v8/deb"
            ;;
        *)
            echo "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    TMP=$(mktemp).deb
    wget -O $TMP $URL
    sudo apt install -y $TMP
    rm -f $TMP
else
    echo "Skipping NoMachine installation."
fi

read -r -p "Do you want to install Rustdesk? [Y/n] "
# Rustdesk
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Installing Rustdesk..."
    TMP=$(mktemp).deb
    URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep url | grep "$(uname -m)\.deb" | cut -d : -f 2,3 | tr -d \")
    wget -O $TMP $(echo $URL)
    sudo apt install -y $TMP
    rm -f $TMP
else
    echo "Skipping Rustdesk installation."
fi

# Easytier
echo "Do you want to install Easytier CLI or GUI?"
read -r -p "1 for CLI, 2 for GUI, any other key to skip: "
if [[ $REPLY == "1" ]]; then
    echo "Installing Easytier CLI..."
    TMP=$(mktemp).zip
    URL=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest | grep easytier-linux-$(uname -m) | grep url | cut -d : -f 2,3 | tr -d \")
    wget -O $TMP $(echo $URL)
    sudo unzip $TMP -d "/opt"
    rm -f $TMP
    sudo mv /opt/easytier-linux-$(uname -m) /opt/easytier
    for FILE in /opt/easytier/*; do
        sudo ln -s $FILE /usr/bin/$(basename $FILE) -v
    done
    sudo mkdir -p /opt/easytier/config
    sudo tee /opt/easytier/config/default.conf > /dev/null << EOF
instance_name = "default"
dhcp = true
listeners = [
    "tcp://0.0.0.0:11010",
    "udp://0.0.0.0:11010",
    "wg://0.0.0.0:11011",
    "ws://0.0.0.0:11011",
    "wss://0.0.0.0:11012",
]
rpc_portal = "0.0.0.0:0"

[[peer]]
uri = "udp://to.be.filled:11010"

[network_identity]
network_name = "to_be_filled"
network_secret = "to_be_filled"

[flags]

EOF
    sudo tee /etc/systemd/system/easytier@.service > /dev/null << EOF
[Unit]
Description=EasyTier Service
Wants=network.target
After=network.target network.service
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=/opt/easytier
ExecStart=/opt/easytier/easytier-core -c /opt/easytier/config/%i.conf
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    echo "Easytier CLI installation complete. Remember to create your own config file based on /opt/easytier/config/default.conf and enable the service using:"
    echo "  sudo systemctl enable --now easytier@<your_config.conf>"
elif [[ $REPLY == "2" ]]; then
    echo "Installing Easytier GUI..."
    TMP=$(mktemp).deb
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    URL=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest | grep easytier-gui | grep url | grep deb | grep $ARCH | cut -d : -f 2,3 | tr -d \")
    wget -O $TMP $(echo $URL)
    sudo apt install -y $TMP
    rm -f $TMP
else
    echo "Skipping Easytier installation."
fi

# SSH Reverse Tunnel for ssh relay
read -r -p "Do you want to set up an SSH reverse tunnel for SSH relay? [Y/n] "
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    sudo tee /etc/systemd/system/reverse-tunnel@.service > /dev/null << EOF
[Unit]
Description=Reverse SSH Tunnel on port %i
After=network-online.target
Wants=network-online.target

[Service]
User=to_be_filled
ExecStart=/usr/bin/ssh \\
    -o ExitOnForwardFailure=yes \\
    -o ServerAliveInterval=30 \\
    -o ServerAliveCountMax=3 \\
    -N -R 0.0.0.0:%i:localhost:22 \\
    -i /to_be_filled/path/to/private_key to_be_filled@to_be_filled.relay.server.com
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    echo "SSH reverse tunnel service created. Remember to replace placeholders in /etc/systemd/system/reverse-tunnel@.service."
    echo "You can enable and start the service using:"
    echo "  sudo systemctl enable --now reverse-tunnel@<remote_port>"
else
    echo "Skipping SSH reverse tunnel setup."
fi

