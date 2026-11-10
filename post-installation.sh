#!/usr/bin/env bash
# This script installs common packages.
set -euo pipefail

# Ubuntu or Debian? (detect early, needed by install functions)
os=$(grep '^ID=' /etc/os-release | cut -d= -f2- | tr -d '"')

# ============================================================================
# TUI Framework Functions
# ============================================================================

# ANSI color codes
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_RED='\033[0;31m'
COLOR_BOLD='\033[1m'

# The menus need whiptail. It ships with Debian and Ubuntu, so this only has
# to install it on stripped-down images.
ensure_tui_available() {
    if command -v whiptail &> /dev/null; then
        return 0
    fi

    echo "whiptail not found. Attempting to install..."
    if ! sudo apt install -y whiptail; then
        echo "Could not install whiptail, which this script needs for its menus."
        exit 1
    fi
    echo "whiptail installed successfully."
}

# Show a yes/no dialog
show_yesno() {
    local title="$1"
    local message="$2"

    whiptail --title "$title" --yesno "$message" 0 0
}

# ============================================================================
# Component Detection Functions
# ============================================================================

# True inside a desktop session. Over SSH this is false even on a desktop
# machine, so only use it for defaults, never to block anything.
has_desktop() {
    [[ -n "${XDG_CURRENT_DESKTOP-}" ]] || [[ -n "${GDMSESSION-}" ]]
}

# Which desktop fcitx5 should be set up for: gnome, kde or other
detect_desktop() {
    case "${XDG_CURRENT_DESKTOP-}" in
        *GNOME*)
            echo "gnome"
            return
            ;;
        *KDE*)
            echo "kde"
            return
            ;;
    esac

    # No session to ask (e.g. over SSH): go by what is installed, if unambiguous
    if [[ -z "${XDG_CURRENT_DESKTOP-}" ]]; then
        if command -v gnome-shell &> /dev/null && ! command -v plasmashell &> /dev/null; then
            echo "gnome"
            return
        fi
        if command -v plasmashell &> /dev/null && ! command -v gnome-shell &> /dev/null; then
            echo "kde"
            return
        fi
    fi
    echo "other"
}

is_deb_installed() {
    [[ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" == ii* ]]
}

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
    # rustdesk-unattended-wayland replaces/conflicts with rustdesk, so accept either.
    is_deb_installed rustdesk || is_deb_installed rustdesk-unattended-wayland
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

RIME_DIR="$HOME/.local/share/fcitx5/rime"
RIME_GRAMMAR_MODEL="$RIME_DIR/wanxiang-lts-zh-hans.gram"

# The grammar model is an option, so it does not count here. The menu label
# says when it is missing (see installed_label).
is_chinese_input_installed() {
    is_deb_installed fcitx5-rime && [ -f "$RIME_DIR/rime_ice.schema.yaml" ]
}

# Text for the [...] tag of an installed component in the menu
installed_label() {
    case "$1" in
        rustdesk)
            if is_deb_installed rustdesk-unattended-wayland; then
                echo "INSTALLED: unattended"
            else
                echo "INSTALLED: regular"
            fi
            ;;
        chinese_input)
            if [ -f "$RIME_GRAMMAR_MODEL" ]; then
                echo "INSTALLED"
            else
                echo "INSTALLED, no grammar model"
            fi
            ;;
        *)
            echo "INSTALLED"
            ;;
    esac
}

# ============================================================================
# Installation Functions
# ============================================================================
#
# main() runs each component installer in a subshell with `set -e`: the first
# failing command fails the component, and `exit` only ends that component.
# Values chosen on the options page are in OPT_VALUE.

# Status an installer returns to stop the whole run because the user has to
# log out and back in before anything else can be installed.
STOP_AND_RELOGIN=10

# Add a line to the "Next steps" block of the final summary. Installers cannot
# change variables of the main shell, so the lines travel through a file.
add_note() {
    echo "$1" >> "$NOTES_DIR/$CURRENT_COMPONENT"
}

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
    if has_desktop; then
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
        # $SHELL only changes after logging back in, and later installers pick
        # the rc file to write to from it, so the run stops here.
        return "$STOP_AND_RELOGIN"
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
        local shell_comp_string=""
        if [ "$SHELL_NAME" == "zsh" ]; then
            shell_comp_string="$(printf '%s\n' \
                '    autoload -Uz compinit' \
                '    compinit')"
        elif [ "$SHELL_NAME" == "bash" ]; then
            shell_comp_string="$(printf '%s\n' \
                '    if [[ -r "/home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh" ]]; then' \
                '        source "/home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh"' \
                '    else' \
                '        for COMPLETION in "/home/linuxbrew/.linuxbrew/etc/bash_completion.d/"*; do' \
                '            [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"' \
                '        done' \
                '    fi')"
        fi
        echo ""
        echo "# Homebrew"
        echo "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
        echo "if type brew &>/dev/null; then"
        echo "$shell_comp_string"
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
        
        sudo apt install -y python3-venv ripgrep fzf fd-find

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
    local variant="${OPT_VALUE[rustdesk.variant]}"
    local debs

    echo "Installing Rustdesk ($variant build)..."
    TMP=$(mktemp).deb
    # A release carries both builds; only the unattended one has "unattended" in its file name
    debs=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep url | grep "$(uname -m)\.deb" | cut -d : -f 2,3 | tr -d '" ') || true
    if [[ "$variant" == "unattended" ]]; then
        URL=$(grep unattended <<< "$debs" || true)
    else
        URL=$(grep -v unattended <<< "$debs" || true)
    fi
    if [[ -z "$URL" ]]; then
        echo "No $variant Rustdesk package for $(uname -m) in the latest release."
        return 1
    fi
    wget -O $TMP "$URL"
    sudo apt install -y $TMP
    rm -f $TMP
    echo "Rustdesk installation complete."

    # If debian, create ldconfig file for Rustdesk since it doesn't come with one and the library won't be found.
    if [[ "$os" == "debian" ]]; then
        echo "Rustdesk on Debian is missing a ldconfig file, creating one..."
        echo "/usr/share/rustdesk/lib" | sudo tee /etc/ld.so.conf.d/rustdesk.conf > /dev/null
        sudo ldconfig
    fi
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
    add_note "Create your own config file based on /opt/easytier/config/default.conf"
    add_note "Enable the service: sudo systemctl enable --now easytier@<config file name without .conf>"
}

install_easytier_gui() {
    echo "Easytier GUI requires pkexec for privilege escalation. Installing pkexec..."
    sudo apt update
    sudo apt install -y pkexec

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
    add_note "Replace the placeholders in /etc/systemd/system/reverse-tunnel@.service"
    add_note "Enable and start the service: sudo systemctl enable --now reverse-tunnel@<remote_port>"
}

# Install rime-ice, and its grammar model if chosen, into the fcitx5 Rime
# directory with plum, the Rime package manager. Run plum from a local clone:
# piping its installer in through curl reports success even when the download
# fails.
install_rime_ice() {
    local plum_dir
    local status=0
    plum_dir=$(mktemp -d) || return 1
    git clone --depth 1 https://github.com/rime/plum.git "$plum_dir" &&
        rime_frontend=fcitx5-rime bash "$plum_dir/rime-install" iDvel/rime-ice ||
        status=1
    if [[ "$status" -eq 0 && "${OPT_VALUE[chinese_input.grammar]}" == "yes" ]]; then
        rime_frontend=fcitx5-rime bash "$plum_dir/rime-install" iDvel/rime-ice:others/recipes/grammar:schema=rime_ice ||
            status=1
    fi
    rm -rf "$plum_dir"
    return "$status"
}

# KDE Plasma. On Wayland, KWin has to start fcitx5 itself, and GTK_IM_MODULE and
# QT_IM_MODULE must stay unset (https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland).
# X11 sessions keep the im-config setup.
setup_fcitx5_kde() {
    local kwriteconfig current
    local env_dir="$HOME/.config/plasma-workspace/env"

    # Same as System Settings > Keyboard > Virtual Keyboard > Fcitx 5. An fcitx5
    # entry that is already selected there stays: fcitx5 ships two of them.
    if ! kwriteconfig=$(command -v kwriteconfig6 || command -v kwriteconfig5); then
        echo "kwriteconfig not found: is KDE Plasma installed?"
        return 1
    fi
    current=$("${kwriteconfig/kwrite/kread}" --file kwinrc --group Wayland --key InputMethod 2> /dev/null || true)
    if [[ "${current,,}" != *fcitx5* ]]; then
        "$kwriteconfig" --file kwinrc --group Wayland --key InputMethod \
            /usr/share/applications/org.fcitx.Fcitx5.desktop || return 1
    fi

    # Replace the file im-config just wrote. It is a shell snippet that
    # im-config sources at login, so it can stand down in the one session where
    # KWin does the work. Without this, a bash login would still get
    # GTK_IM_MODULE and QT_IM_MODULE and a second fcitx5 from im-config.
    cat > "$HOME/.xinputrc" << 'EOF' || return 1
# Written by .dotfiles/post-installation.sh. im-config treats this file as
# manually managed; delete it to configure im-config yourself.
# Plasma on Wayland: KWin starts fcitx5, so im-config does nothing there.
if [ "$XDG_SESSION_TYPE" != "wayland" ] || [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    run_im fcitx5
fi
EOF

    # Plasma sources this at session start, whatever the login shell is. It
    # applies assignments only, so an `unset` here would have no effect.
    mkdir -p "$env_dir" || return 1
    cat > "$env_dir/fcitx5.sh" << 'EOF'
# Written by .dotfiles/post-installation.sh.
# Plasma on Wayland: apps reach fcitx5 through KWin, only XWayland apps need this.
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export XMODIFIERS=@im=fcitx
fi
EOF
}

# GNOME. On Wayland nothing starts fcitx5 or sets its variables reliably:
# im-config reaches Wayland sessions only through /etc/profile.d, which a zsh
# login does not read, and from version 0.59 it skips Wayland altogether. So
# both are done here in a way GDM applies whatever the login shell is.
# GTK_IM_MODULE stays unset, as the fcitx docs recommend for GNOME.
setup_fcitx5_gnome() {
    # Not whichever gsettings is first in PATH: Homebrew's lacks the GNOME schemas
    local gsettings=/usr/bin/gsettings
    local schema=org.gnome.settings-daemon.plugins.xsettings
    local env_dir="$HOME/.config/environment.d"
    local autostart_dir="$HOME/.config/autostart"
    local overrides

    mkdir -p "$autostart_dir" "$env_dir" || return 1
    cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$autostart_dir/" || return 1
    cat > "$env_dir/fcitx5.conf" << 'EOF' || return 1
# Written by .dotfiles/post-installation.sh
XMODIFIERS=@im=fcitx
QT_IM_MODULE=fcitx
EOF

    # Makes GTK apps that run on X11 or XWayland use fcitx. The setting is one
    # dictionary, so it is only written when nothing else is in it.
    overrides=$("$gsettings" get "$schema" overrides 2> /dev/null || true)
    if [[ "$overrides" != *"'Gtk/IMModule': <'fcitx'>"* ]]; then
        if [[ "$overrides" != "@a{sv} {}" ]] ||
            ! "$gsettings" set "$schema" overrides "{'Gtk/IMModule':<'fcitx'>}"; then
            add_note "Add 'Gtk/IMModule':<'fcitx'> to the overrides of $schema (gsettings), from a GNOME session"
        fi
    fi

    # Kimpanel draws the candidate window; without it the window cannot show
    # over GNOME Shell's own UI. Debian packages it, Ubuntu does not.
    if apt-cache show gnome-shell-extension-kimpanel &> /dev/null; then
        sudo apt install -y gnome-shell-extension-kimpanel || return 1
        add_note "Enable the Kimpanel extension in the Extensions app"
    else
        add_note "Install the Kimpanel extension: https://extensions.gnome.org/extension/261/kimpanel/"
    fi
}

install_chinese_input() {
    local status=0
    local themes="$HOME/.local/share/fcitx5/themes"
    local desktop="${OPT_VALUE[chinese_input.desktop]}"
    local -a packages=(git curl wget fcitx5 fcitx5-chinese-addons fcitx5-rime
        fcitx5-config-qt im-config librime-plugin-lua librime-plugin-octagram)

    if [[ "$desktop" == "kde" ]]; then
        packages+=(kde-config-fcitx5)
    fi

    echo "Installing fcitx5 with Rime..."
    sudo apt install -y "${packages[@]}" || return 1

    # im-config covers X11 sessions on every desktop. It refuses to touch a
    # hand-edited ~/.xinputrc, and counts the one setup_fcitx5_kde writes as such.
    if grep -qs 'post-installation.sh' "$HOME/.xinputrc"; then
        rm -f "$HOME/.xinputrc"
    fi
    im-config -n fcitx5 || return 1

    case "$desktop" in
        kde)
            echo "Setting up fcitx5 for KDE Plasma..."
            setup_fcitx5_kde || status=1
            ;;
        gnome)
            echo "Setting up fcitx5 for GNOME..."
            setup_fcitx5_gnome || status=1
            ;;
    esac

    echo "Installing rime-ice..."
    install_rime_ice || status=1

    echo "Installing Fluent themes for fcitx5..."
    mkdir -p "$themes"
    wget -qO- https://github.com/Reverier-Xu/Fluent-fcitx5/archive/refs/heads/master.tar.gz |
        tar -xz -C "$themes" --strip-components=1 --wildcards '*/Fluent*' || status=1

    add_note "After logging back in, run fcitx5-configtool to add Rime, deploy it, change keymaps and pick a Fluent theme"
    return "$status"
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
    "chinese_input"
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
    ["chinese_input"]="fcitx5 + rime-ice"
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
    ["chinese_input"]="is_chinese_input_installed"
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
    ["chinese_input"]="install_chinese_input"
)

# Components only useful with a desktop. Without one detected they start
# unchecked in the menu, but can still be selected.
declare -A COMP_REQUIRES_DESKTOP=(
    ["chinese_input"]=1
)

# Whether a component that isn't installed yet starts checked in the menu
is_default_selected() {
    [[ -z "${COMP_REQUIRES_DESKTOP[$1]-}" ]] || has_desktop
}

# What a component needs, once installed, before it is usable, as
# "<level>|<reason>". restart_need has the cases that depend on an option.
declare -A COMP_RESTART=(
    ["zsh"]="terminal|Oh My Zsh set up in ~/.zshrc"
    ["homebrew"]="terminal|shell rc file changed"
    ["miniconda"]="terminal|shell rc file changed"
    ["neovim"]="terminal|shell rc file changed"
    ["docker"]="relogin|added to the docker group"
    ["chinese_input"]="relogin|input method switched to fcitx5"
)

# Strongest first
declare -a RESTART_LEVELS=("reboot" "relogin" "terminal")

declare -A RESTART_LABELS=(
    ["reboot"]="Reboot"
    ["relogin"]="Log out and in"
    ["terminal"]="New terminal"
)

restart_need() {
    # GNOME gets the fcitx5 variables from ~/.config/environment.d, and the
    # fcitx docs advise a reboot for changes there to take effect
    if [[ "$1" == "chinese_input" && "${OPT_VALUE[chinese_input.desktop]}" == "gnome" ]]; then
        echo "reboot|input method switched to fcitx5"
        return
    fi
    echo "${COMP_RESTART[$1]-}"
}

# ============================================================================
# Component Options
# ============================================================================

# Options are named "<component>.<option>" and are all pick-one lists. The
# options page offers those of the selected components, and installers read
# the chosen value from OPT_VALUE.
declare -a OPTIONS=(
    "rustdesk.variant"
    "chinese_input.grammar"
    "chinese_input.desktop"
)

declare -A OPT_NAMES=(
    ["rustdesk.variant"]="RustDesk build"
    ["chinese_input.grammar"]="rime-ice grammar model"
    ["chinese_input.desktop"]="Desktop to set fcitx5 up for"
)

# Choice ids, space-separated
declare -A OPT_CHOICES=(
    ["rustdesk.variant"]="regular unattended"
    ["chinese_input.grammar"]="yes no"
    ["chinese_input.desktop"]="gnome kde other"
)

declare -A OPT_CHOICE_NAMES=(
    ["rustdesk.variant.regular"]="Regular"
    ["rustdesk.variant.unattended"]="Unattended Wayland (preview)"
    ["chinese_input.grammar.yes"]="Yes (about 400 MB)"
    ["chinese_input.grammar.no"]="No"
    ["chinese_input.desktop.gnome"]="GNOME"
    ["chinese_input.desktop.kde"]="KDE Plasma"
    ["chinese_input.desktop.other"]="Other (X11 sessions only)"
)

declare -A OPT_VALUE=()

# Give every option its starting value, going by the state of this machine
init_option_defaults() {
    OPT_VALUE["rustdesk.variant"]="regular"
    if [[ "$(uname -m)" != "x86_64" ]]; then
        # The unattended build is x86_64 only, which leaves nothing to choose
        OPT_CHOICES["rustdesk.variant"]="regular"
    elif is_deb_installed rustdesk-unattended-wayland; then
        OPT_VALUE["rustdesk.variant"]="unattended"
    fi
    OPT_VALUE["chinese_input.grammar"]="yes"
    OPT_VALUE["chinese_input.desktop"]=$(detect_desktop)
}

# Print the options of the given components that have more than one choice
active_options() {
    local opt
    local -a choices

    for opt in "${OPTIONS[@]}"; do
        if [[ " $* " != *" ${opt%%.*} "* ]]; then
            continue
        fi
        choices=(${OPT_CHOICES[$opt]})
        if [ ${#choices[@]} -gt 1 ]; then
            echo "$opt"
        fi
    done
}

# An option and its current value, e.g. "RustDesk build: Regular"
option_summary() {
    local key="$1.${OPT_VALUE[$1]}"
    echo "${OPT_NAMES[$1]}: ${OPT_CHOICE_NAMES[$key]}"
}

# ============================================================================
# Menus
# ============================================================================

# Checklist of components. Prints the selected ones, or nothing on cancel.
show_component_menu() {
    local -a menu_args=()
    local comp name result

    for comp in "${COMPONENTS[@]}"; do
        name="${COMP_NAMES[$comp]}"
        if ${COMP_DETECT[$comp]}; then
            # Installed - show with tag, default OFF
            menu_args+=("$comp" "[$(installed_label "$comp")] $name" "OFF")
        elif is_default_selected "$comp"; then
            # Not installed - default ON
            menu_args+=("$comp" "$name" "ON")
        else
            # Not installed, but needs a desktop that wasn't detected - default OFF
            menu_args+=("$comp" "$name" "OFF")
        fi
    done

    result=$(whiptail --title "Component Installation" \
        --checklist "Select components to install (Space to toggle, Enter to confirm):" \
        0 0 0 "${menu_args[@]}" \
        3>&1 1>&2 2>&3) || return 0

    # whiptail puts each selected tag in quotes
    echo "$result" | tr -d '"'
}

# Pick-one list for a single option
edit_option() {
    local opt="$1"
    local -a radio_args=()
    local choice state result

    for choice in ${OPT_CHOICES[$opt]}; do
        state="OFF"
        if [[ "$choice" == "${OPT_VALUE[$opt]}" ]]; then
            state="ON"
        fi
        radio_args+=("$choice" "${OPT_CHOICE_NAMES[$opt.$choice]}" "$state")
    done

    if result=$(whiptail --title "${OPT_NAMES[$opt]}" --notags \
        --radiolist "Space to select, Enter to confirm:" \
        0 0 0 "${radio_args[@]}" \
        3>&1 1>&2 2>&3) && [[ -n "$result" ]]; then
        OPT_VALUE[$opt]="$result"
    fi
}

# Settings page: one row per given option, showing its current value. It
# changes OPT_VALUE, so it must not run in a subshell. Returns 1 on cancel.
show_options_page() {
    local -a menu_args
    local opt choice

    while true; do
        menu_args=()
        for opt in "$@"; do
            menu_args+=("$opt" "$(option_summary "$opt")")
        done
        menu_args+=("continue" "Continue")

        choice=$(whiptail --title "Component Options" --notags \
            --default-item "continue" --ok-button "Select" \
            --menu "Press Enter on an option to change it, or on Continue to go on:" \
            0 0 0 "${menu_args[@]}" \
            3>&1 1>&2 2>&3) || return 1

        if [[ "$choice" == "continue" ]]; then
            return 0
        fi
        edit_option "$choice"
    done
}

# ============================================================================
# Main Execution
# ============================================================================

# Outcome of the run, filled by main() for print_summary
declare -a DONE_OK=()
declare -a DONE_FAILED=()
declare -a NOT_ATTEMPTED=()
STOPPED_AT=""

# Results, restart needs and follow-up notes, all in one place at the end
print_summary() {
    local comp level need note
    local -a restart_lines=()
    local -a noted=()

    echo ""
    echo "=========================================================================="
    echo "                    Installation Complete!"
    echo "=========================================================================="

    if [ ${#DONE_OK[@]} -gt 0 ]; then
        echo ""
        echo -e "${COLOR_BOLD}Installed (${#DONE_OK[@]}):${COLOR_RESET}"
        for comp in "${DONE_OK[@]}"; do
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COMP_NAMES[$comp]}"
        done
    fi

    if [ ${#DONE_FAILED[@]} -gt 0 ]; then
        echo ""
        echo -e "${COLOR_BOLD}Failed (${#DONE_FAILED[@]}):${COLOR_RESET}"
        for comp in "${DONE_FAILED[@]}"; do
            echo -e "  ${COLOR_RED}✗${COLOR_RESET} ${COMP_NAMES[$comp]}"
        done
    fi

    if [ ${#NOT_ATTEMPTED[@]} -gt 0 ]; then
        echo ""
        echo -e "${COLOR_BOLD}Not attempted (${#NOT_ATTEMPTED[@]}):${COLOR_RESET}"
        for comp in "${NOT_ATTEMPTED[@]}"; do
            echo -e "  ${COLOR_YELLOW}-${COLOR_RESET} ${COMP_NAMES[$comp]}"
        done
    fi

    for level in "${RESTART_LEVELS[@]}"; do
        if [[ "$level" == "relogin" && -n "$STOPPED_AT" ]]; then
            restart_lines+=("$(printf '  %-15s %s (login shell changed; run this script again afterwards)' \
                "${RESTART_LABELS[$level]}" "${COMP_NAMES[$STOPPED_AT]}")")
        fi
        for comp in "${DONE_OK[@]}"; do
            need=$(restart_need "$comp")
            if [[ "${need%%|*}" == "$level" ]]; then
                restart_lines+=("$(printf '  %-15s %s (%s)' \
                    "${RESTART_LABELS[$level]}" "${COMP_NAMES[$comp]}" "${need#*|}")")
            fi
        done
    done
    if [ ${#restart_lines[@]} -gt 0 ]; then
        echo ""
        echo -e "${COLOR_BOLD}Restart needed:${COLOR_RESET}"
        printf '%s\n' "${restart_lines[@]}"
    fi

    for comp in "${DONE_OK[@]}"; do
        if [ -s "$NOTES_DIR/$comp" ]; then
            noted+=("$comp")
        fi
    done
    if [ ${#noted[@]} -gt 0 ]; then
        echo ""
        echo -e "${COLOR_BOLD}Next steps:${COLOR_RESET}"
        for comp in "${noted[@]}"; do
            echo "  ${COMP_NAMES[$comp]}"
            while IFS= read -r note; do
                echo "    - $note"
            done < "$NOTES_DIR/$comp"
        done
    fi
    echo ""
}

main() {
    local -a selected_components
    local -a options
    local comp opt confirm_message rc i

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
    selected_components=($(show_component_menu))

    # Check if any components were selected
    if [ ${#selected_components[@]} -eq 0 ]; then
        echo ""
        echo "No components selected. Exiting."
        exit 0
    fi

    # Let the user adjust the options of the selected components
    init_option_defaults
    options=($(active_options "${selected_components[@]}"))
    if [ ${#options[@]} -gt 0 ]; then
        if ! show_options_page "${options[@]}"; then
            echo "Installation cancelled."
            exit 0
        fi
    fi

    # Confirm installation
    confirm_message="The following components will be installed:\n\n"
    for comp in "${selected_components[@]}"; do
        confirm_message+="- ${COMP_NAMES[$comp]}\n"
        for opt in "${options[@]}"; do
            if [[ "${opt%%.*}" == "$comp" ]]; then
                confirm_message+="    $(option_summary "$opt")\n"
            fi
        done
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

    NOTES_DIR=$(mktemp -d)
    trap 'rm -rf "$NOTES_DIR"' EXIT

    for i in "${!selected_components[@]}"; do
        comp="${selected_components[$i]}"
        echo ""
        echo -e "${COLOR_CYAN}${COLOR_BOLD}>>> Installing: ${COMP_NAMES[$comp]}${COLOR_RESET}"
        echo ""

        # The subshell must not run as an `if` condition or in a && / || list:
        # bash ignores `set -e` inside those, and a failed step would then go
        # unnoticed, with the installer still returning success.
        CURRENT_COMPONENT="$comp"
        set +e
        (
            set -e
            "${COMP_INSTALL[$comp]}"
        )
        rc=$?
        set -e

        if [ "$rc" -eq 0 ]; then
            DONE_OK+=("$comp")
        elif [ "$rc" -eq "$STOP_AND_RELOGIN" ]; then
            STOPPED_AT="$comp"
            NOT_ATTEMPTED=("${selected_components[@]:i+1}")
            break
        else
            DONE_FAILED+=("$comp")
        fi
    done

    print_summary
}

# Run main function
# Only run if the script is being executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
