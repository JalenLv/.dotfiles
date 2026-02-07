#!/usr/bin/env bash
# This script installs common packages.
set -euo pipefail

# Ubuntu or Debian? (detect early, needed by install functions)
os=$(grep '^ID=' /etc/os-release | cut -d= -f2- | tr -d '"')

# ============================================================================
# TUI Framework Functions
# ============================================================================

# ANSI color codes for enhanced_read mode
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_RED='\033[0;31m'
COLOR_BOLD='\033[1m'

# Global variable to track TUI mode
TUI_MODE="enhanced_read"  # Default to enhanced read, will switch to whiptail if available

# Ensure TUI is available (whiptail first, try install, then fallback)
ensure_tui_available() {
    if command -v whiptail &> /dev/null; then
        TUI_MODE="whiptail"
        return 0
    fi
    
    # Try to install whiptail
    echo "whiptail not found. Attempting to install..."
    if sudo apt install -y whiptail; then
        TUI_MODE="whiptail"
        echo "whiptail installed successfully."
        return 0
    fi
    
    # Fallback to enhanced read
    echo "Could not install whiptail. Using text-based interface."
    TUI_MODE="enhanced_read"
    return 0
}

# Show a yes/no dialog
show_yesno() {
    local title="$1"
    local message="$2"
    
    if [[ "$TUI_MODE" == "whiptail" ]]; then
        whiptail --title "$title" --yesno "$message" 0 0
        return $?
    else
        echo -e "${COLOR_CYAN}${COLOR_BOLD}=== $title ===${COLOR_RESET}"
        echo -e "$message"
        read -r -p "Continue? [Y/n] " reply
        if [[ $reply =~ ^[Yy]$ ]] || [[ -z $reply ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# ============================================================================
# Component Detection Functions
# ============================================================================

is_zsh_installed() {
    command -v zsh &> /dev/null && [ -d "$HOME/.oh-my-zsh" ]
}

is_jetbrains_font_installed() {
    [ -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" ]
}

is_homebrew_installed() {
    command -v brew &> /dev/null || [ -d "/home/linuxbrew/.linuxbrew" ]
}

is_miniconda_installed() {
    command -v conda &> /dev/null || [ -d "$HOME/miniconda3" ]
}

is_neovim_installed() {
    command -v nvim &> /dev/null
}

is_vscode_installed() {
    dpkg -l code 2>/dev/null | grep -q '^ii'
}

is_docker_installed() {
    command -v docker &> /dev/null
}

is_nomachine_installed() {
    dpkg -l nomachine 2>/dev/null | grep -q '^ii'
}

is_rustdesk_installed() {
    dpkg -l rustdesk 2>/dev/null | grep -q '^ii'
}

is_easytier_cli_installed() {
    [ -d /opt/easytier ]
}

is_easytier_gui_installed() {
    dpkg -l easytier-gui 2>/dev/null | grep -q '^ii'
}

is_ssh_tunnel_service_installed() {
    [ -f /etc/systemd/system/reverse-tunnel@.service ]
}

# ============================================================================
# Installation Functions
# ============================================================================

install_common_packages() {
    COMMON_PACKAGES=(
        git
        curl
        wget
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
    # If there is desktop environment install vim-gtk3 else isntall vim
    if [[ -n "${XDG_CURRENT_DESKTOP-}" ]] || [[ -n "${GDMSESSION-}" ]]; then
        COMMON_PACKAGES+=(vim-gtk3)
    else
        COMMON_PACKAGES+=(vim)
    fi
    echo "Installing common packages..."
    sudo apt install -y "${COMMON_PACKAGES[@]}"
    
    echo "Upgrading existing packages..."
    sudo apt upgrade -y
}

install_zsh() {
    echo "Installing Zsh and Oh My Zsh..."
    SHELL_NAME=$(basename "$SHELL")
    if [[ "$SHELL_NAME" != "zsh" ]]; then
        echo "Installing Zsh..."
        sudo apt install -y zsh
        chsh -s "$(which zsh)"
        echo "Please log out and log back in to start using Zsh as your default shell."
        echo "After logging back in, run this script again to continue with remaining installations."
        exit 0
    fi
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo "Zsh and Oh My Zsh installation complete."
}

install_jetbrains_font() {
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
}

install_homebrew() {
    echo "Downloading Homebrew..."
    TMP=$(mktemp)
    curl -o $TMP https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 bash $TMP
    
    rm -f $TMP
    
    echo "Running Homebrew post-installation steps..."
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
    echo "Homebrew installation complete."
}

install_miniconda() {
    echo "Downloading Miniconda installer..."
    TMP=$(mktemp).sh
    curl -o $TMP https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh
    
    echo "Installing Miniconda at $HOME/miniconda3..."
    bash $TMP -b -p "$HOME/miniconda3"
    
    rm -f $TMP
    
    echo "Initializing Miniconda..."
    "$HOME/miniconda3/bin/conda" init $(basename "$SHELL")
    echo "Miniconda installation complete."
}

install_neovim() {
    echo "Installing Neovim from Homebrew..."
    echo "This installs Node.js and tree-sitter-cli from Homebrew as dependencies."
    echo "This also installs neovim module in conda's base environment."
    
    # Check dependencies
    if ! is_homebrew_installed; then
        echo "Error: Homebrew is required for Neovim installation."
        echo "Please install Homebrew first."
        return 1
    fi
    
    if ! is_miniconda_installed; then
        echo "Error: Miniconda is required for Neovim installation."
        echo "Please install Miniconda first."
        return 1
    fi
    
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
            echo "export PATH=\"/home/linuxbrew/.linuxbrew/opt/node@24/bin:\$PATH\""
        } >> "$SHELL_RC"
        
        export PATH="/home/linuxbrew/.linuxbrew/opt/node@24/bin:$PATH"
        export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
        corepack enable
        corepack prepare yarn@stable --activate
        
        brew install tree-sitter-cli
        
        source $HOME/miniconda3/etc/profile.d/conda.sh
        conda activate base

        conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
        conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
        conda install -y -q python=3.13

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
}

install_vscode() {
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
    echo "Visual Studio Code installation complete."
}

install_docker() {
    # Remove old versions of Docker if they exist
    echo "Removing old versions of Docker if they exist..."
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc 2>/dev/null | cut -f1) 2>/dev/null || true
    
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
    echo "Docker installation complete."
}

install_nomachine() {
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
    echo "NoMachine installation complete."
}

install_rustdesk() {
    echo "Installing Rustdesk..."
    TMP=$(mktemp).deb
    URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep url | grep "$(uname -m)\.deb" | cut -d : -f 2,3 | tr -d \")
    wget -O $TMP $(echo $URL)
    sudo apt install -y $TMP
    rm -f $TMP
    echo "Rustdesk installation complete."
}

install_easytier_cli() {
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
    sudo tee /opt/easytier/config/default.conf > /dev/null << 'EOF'
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
    sudo tee /etc/systemd/system/easytier@.service > /dev/null << 'EOF'
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
    echo "Easytier CLI installation complete."
    echo "Remember to create your own config file based on /opt/easytier/config/default.conf"
    echo "Enable the service using: sudo systemctl enable --now easytier@<your_config.conf>"
}

install_easytier_gui() {
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
    echo "Easytier GUI installation complete."
}

install_ssh_tunnel_service() {
    echo "Setting up SSH reverse tunnel service..."
    sudo tee /etc/systemd/system/reverse-tunnel@.service > /dev/null << 'EOF'
[Unit]
Description=Reverse SSH Tunnel on port %i
After=network-online.target
Wants=network-online.target

[Service]
User=to_be_filled
ExecStart=/usr/bin/ssh \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -N -R 0.0.0.0:%i:localhost:22 \
    -i /to_be_filled/path/to/private_key to_be_filled@to_be_filled.relay.server.com
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    echo "SSH reverse tunnel service created."
    echo "Remember to replace placeholders in /etc/systemd/system/reverse-tunnel@.service."
    echo "Enable and start the service using: sudo systemctl enable --now reverse-tunnel@<remote_port>"
}

# ============================================================================
# Component Registry and Menu System
# ============================================================================

# Component definitions
declare -a COMPONENTS=(
    "zsh"
    "font"
    "homebrew"
    "miniconda"
    "neovim"
    "vscode"
    "docker"
    "nomachine"
    "rustdesk"
    "easytier_cli"
    "easytier_gui"
    "ssh_tunnel"
)

declare -A COMP_NAMES=(
    ["zsh"]="Zsh + Oh My Zsh"
    ["font"]="JetBrains Mono Nerd Font"
    ["homebrew"]="Homebrew Package Manager"
    ["miniconda"]="Miniconda (Python)"
    ["neovim"]="Neovim (requires Homebrew & Miniconda)"
    ["vscode"]="Visual Studio Code"
    ["docker"]="Docker"
    ["nomachine"]="NoMachine Remote Desktop"
    ["rustdesk"]="RustDesk Remote Desktop"
    ["easytier_cli"]="EasyTier VPN (CLI)"
    ["easytier_gui"]="EasyTier VPN (GUI)"
    ["ssh_tunnel"]="SSH Reverse Tunnel Service Template"
)

declare -A COMP_DETECT=(
    ["zsh"]="is_zsh_installed"
    ["font"]="is_jetbrains_font_installed"
    ["homebrew"]="is_homebrew_installed"
    ["miniconda"]="is_miniconda_installed"
    ["neovim"]="is_neovim_installed"
    ["vscode"]="is_vscode_installed"
    ["docker"]="is_docker_installed"
    ["nomachine"]="is_nomachine_installed"
    ["rustdesk"]="is_rustdesk_installed"
    ["easytier_cli"]="is_easytier_cli_installed"
    ["easytier_gui"]="is_easytier_gui_installed"
    ["ssh_tunnel"]="is_ssh_tunnel_service_installed"
)

declare -A COMP_INSTALL=(
    ["zsh"]="install_zsh"
    ["font"]="install_jetbrains_font"
    ["homebrew"]="install_homebrew"
    ["miniconda"]="install_miniconda"
    ["neovim"]="install_neovim"
    ["vscode"]="install_vscode"
    ["docker"]="install_docker"
    ["nomachine"]="install_nomachine"
    ["rustdesk"]="install_rustdesk"
    ["easytier_cli"]="install_easytier_cli"
    ["easytier_gui"]="install_easytier_gui"
    ["ssh_tunnel"]="install_ssh_tunnel_service"
)

# Build and show component selection menu
show_component_menu() {
    local -a selected_components=()
    
    if [[ "$TUI_MODE" == "whiptail" ]]; then
        # Build whiptail checklist arguments
        local -a menu_args=()
        for comp in "${COMPONENTS[@]}"; do
            local detect_func="${COMP_DETECT[$comp]}"
            local name="${COMP_NAMES[$comp]}"
            
            if $detect_func; then
                # Installed - show with tag, default OFF
                menu_args+=("$comp" "[INSTALLED] $name" "OFF")
            else
                # Not installed - default ON
                menu_args+=("$comp" "$name" "ON")
            fi
        done
        
        # Show checklist
        local result
        result=$(whiptail --title "Component Installation" \
            --checklist "Select components to install (Space to toggle, Enter to confirm):" \
            0 0 0 "${menu_args[@]}" \
            3>&1 1>&2 2>&3)
        
        # Parse result
        if [ $? -eq 0 ]; then
            # Remove quotes and convert to array
            result=$(echo "$result" | tr -d '"')
            selected_components=($result)
        fi
    else
        # Enhanced read mode
        # All interactive UI goes to stderr (>&2) so it's not captured by command substitution
        # Only the final result goes to stdout
        local -a toggle_status=()
        
        # Initialize toggle status
        for comp in "${COMPONENTS[@]}"; do
            local detect_func="${COMP_DETECT[$comp]}"
            if $detect_func; then
                toggle_status+=(0)  # Installed, default off
            else
                toggle_status+=(1)  # Not installed, default on
            fi
        done
        
        # Display menu
        while true; do
            # Clear screen for clean display
            clear >&2
            
            echo -e "${COLOR_CYAN}${COLOR_BOLD}" >&2
            echo "================================================================================" >&2
            echo "                    Component Installation Menu" >&2
            echo "================================================================================" >&2
            echo -e "${COLOR_RESET}" >&2
            echo "" >&2

            # Count selected items
            local selected_count=0
            for status in "${toggle_status[@]}"; do
                if [ $status -eq 1 ]; then
                    selected_count=$((selected_count + 1))
                fi
            done

            idx=0
            for comp in "${COMPONENTS[@]}"; do
                local detect_func="${COMP_DETECT[$comp]}"
                local name="${COMP_NAMES[$comp]}"
                local status_marker=""
                local num_display=$(printf "%2d" $((idx+1)))
                
                if $detect_func; then
                    # Installed
                    if [ ${toggle_status[$idx]} -eq 1 ]; then
                        status_marker="${COLOR_YELLOW}[x]${COLOR_RESET}"
                    else
                        status_marker="[ ]"
                    fi
                    echo -e " ${num_display}. $status_marker $name ${COLOR_GREEN}✓ INSTALLED${COLOR_RESET}" >&2
                else
                    # Not installed
                    if [ ${toggle_status[$idx]} -eq 1 ]; then
                        status_marker="${COLOR_YELLOW}[x]${COLOR_RESET}"
                    else
                        status_marker="[ ]"
                    fi
                    echo -e " ${num_display}. $status_marker $name" >&2
                fi
                idx=$((idx + 1))
            done
            
            echo "" >&2
            echo -e "${COLOR_CYAN}${COLOR_BOLD}Selected: $selected_count component(s)${COLOR_RESET}" >&2
            echo "" >&2
            echo -e "${COLOR_CYAN}Commands:${COLOR_RESET}" >&2
            echo "  - Enter numbers to toggle (space-separated, e.g., '1 3 5')" >&2
            echo "  - 'A' to select all" >&2
            echo "  - 'N' to select none" >&2
            echo -e "  - Press ${COLOR_BOLD}Enter${COLOR_RESET} to continue with selected items" >&2
            echo "" >&2
            echo -n "Your choice: " >&2
            read -r input </dev/tty
            
            # If empty, break and proceed
            if [[ -z "$input" ]]; then
                break
            fi
            
            # Handle special commands
            if [[ "$input" == "a" ]] || [[ "$input" == "A" ]]; then
                for i in "${!toggle_status[@]}"; do
                    toggle_status[$i]=1
                done
                continue
            elif [[ "$input" == "n" ]] || [[ "$input" == "N" ]]; then
                for i in "${!toggle_status[@]}"; do
                    toggle_status[$i]=0
                done
                continue
            fi
            
            # Toggle specified items
            for num in $input; do
                if [[ "$num" =~ ^[0-9]+$ ]]; then
                    local idx=$((num - 1))
                    if [ $idx -ge 0 ] && [ $idx -lt ${#COMPONENTS[@]} ]; then
                        if [ ${toggle_status[$idx]} -eq 1 ]; then
                            toggle_status[$idx]=0
                        else
                            toggle_status[$idx]=1
                        fi
                    fi
                fi
            done
        done
        
        # Build selected components array
        idx=0
        for comp in "${COMPONENTS[@]}"; do
            if [ ${toggle_status[$idx]} -eq 1 ]; then
                selected_components+=("$comp")
            fi
            idx=$((idx + 1))
        done
    fi
    
    # Return selected components
    echo "${selected_components[@]}"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Check if apt is available
    if ! command -v apt &> /dev/null; then
        echo "apt package manager not found. This script is intended for Debian-based systems."
        exit 1
    fi
    
    echo "=========================================================================="
    echo "        Debian/Ubuntu Post-Installation Setup Script"
    echo "=========================================================================="
    echo ""
    
    # Update package lists
    echo "Updating package lists... (also grant sudo permissions upfront)"
    sudo apt update

    # Ensure TUI is available
    echo ""
    ensure_tui_available
    
    # Install common packages first
    echo ""
    if show_yesno "Install Common Packages" "Install essential packages (git, curl, wget, vim, htop, build-essential, etc.)?\n\nThis is recommended for most users."; then
        install_common_packages
    else
        echo "Skipping common packages installation."
    fi
    
    # Show component selection menu
    echo ""
    local selected_components
    selected_components=($(show_component_menu))
    
    # Check if any components were selected
    if [ ${#selected_components[@]} -eq 0 ]; then
        echo ""
        echo "No components selected. Exiting."
        exit 0
    fi
    
    # Confirm installation
    local confirm_message=""
    confirm_message+="The following components will be installed:\n\n"
    for comp in "${selected_components[@]}"; do
        confirm_message+="- ${COMP_NAMES[$comp]}\n"
    done
    confirm_message+="\nDo you want to proceed with the installation?"
    if ! show_yesno "Confirm Installation" "$confirm_message"; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Install selected components
    echo ""
    echo "=========================================================================="
    echo "                    Starting Installation"
    echo "=========================================================================="
    echo ""
    
    for comp in "${selected_components[@]}"; do
        echo ""
        echo -e "${COLOR_CYAN}${COLOR_BOLD}>>> Installing: ${COMP_NAMES[$comp]}${COLOR_RESET}"
        echo ""
        
        local install_func="${COMP_INSTALL[$comp]}"
        if $install_func; then
            echo -e "${COLOR_GREEN}✓ ${COMP_NAMES[$comp]} installed successfully${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}✗ ${COMP_NAMES[$comp]} installation failed${COLOR_RESET}"
        fi
    done
    
    # Show completion message
    echo ""
    echo "=========================================================================="
    echo "                    Installation Complete!"
    echo "=========================================================================="
    echo ""
    echo "All selected components have been processed."
    echo "You may need to restart your terminal or log out/in for some changes to take effect."
    echo ""
}

# Run main function
# Only run if the script is being executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

