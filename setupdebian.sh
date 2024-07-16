#!/bin/sh -e

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

# Install required packages using apt (for Debian-based distros)
sudo apt update
sudo apt install -y bash bash-completion tar bat tree multitail wget unzip fontconfig curl git

# Check if the home directory and linuxtoolbox folder exist, create them if they don't
LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

if [ ! -d "$LINUXTOOLBOXDIR" ]; then
    echo "${YELLOW}Creating linuxtoolbox directory: $LINUXTOOLBOXDIR${RC}"
    mkdir -p "$LINUXTOOLBOXDIR"
    echo "${GREEN}linuxtoolbox directory created: $LINUXTOOLBOXDIR${RC}"
fi

if [ -d "$LINUXTOOLBOXDIR/mybash" ]; then rm -rf "$LINUXTOOLBOXDIR/mybash"; fi

echo "${YELLOW}Cloning mybash repository into: $LINUXTOOLBOXDIR/mybash${RC}"
git clone https://github.com/mews-se/mybash "$LINUXTOOLBOXDIR/mybash"
if [ $? -eq 0 ]; then
    echo "${GREEN}Successfully cloned mybash repository${RC}"
else
    echo "${RED}Failed to clone mybash repository${RC}"
    exit 1
fi

# add variables to top level so can easily be accessed by all functions
PACKAGER="apt"
SUDO_CMD="sudo"
SUGROUP="sudo"
GITPATH=""

cd "$LINUXTOOLBOXDIR/mybash" || exit

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkEnv() {
    ## Check Package Handler (only apt for Debian-based distros)
    PACKAGER="apt"

    ## Check if sudo is available
    if ! command_exists sudo; then
        echo "${RED}To run me, you need 'sudo'${RC}"
        exit 1
    fi

    SUDO_CMD="sudo"
    echo "Using $SUDO_CMD as privilege escalation software"

    ## Check if the current directory is writable.
    GITPATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$GITPATH" ]; then
        echo "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi

    ## Check if member of the sudo group.
    if ! groups | grep -q "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

# Check to see if the FiraCode Nerd Font is installed (Change this to whatever font you would like)
FONT_NAME="FiraCode Nerd Font"
if fc-list :family | grep -iq "$FONT_NAME"; then
    echo "Font '$FONT_NAME' is installed."
else
    echo "Installing font '$FONT_NAME'"
    # Change this URL to correspond with the correct font
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/FiraCode.zip"
    FONT_DIR="$HOME/.local/share/fonts"
    wget "$FONT_URL" -O "${FONT_NAME}.zip"
    unzip "${FONT_NAME}.zip" -d "$FONT_NAME"
    mkdir -p "$FONT_DIR"
    mv "$FONT_NAME"/*.ttf "$FONT_DIR/"
    # Update the font cache
    fc-cache -fv
    # delete the files created from this
    rm -rf "$FONT_NAME" "${FONT_NAME}.zip"
    echo "'$FONT_NAME' installed successfully."
fi

installStarshipAndFzf() {
    if command_exists starship; then
        echo "Starship already installed"
        return
    fi

    if ! curl -sS https://starship.rs/install.sh | sh; then
        echo "${RED}Something went wrong during starship install!${RC}"
        exit 1
    fi
    if command_exists fzf; then
        echo "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

create_fastfetch_config() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    
    if [ ! -d "$USER_HOME/.config/fastfetch" ]; then
        mkdir -p "$USER_HOME/.config/fastfetch"
    fi
    # Check if the fastfetch config file exists
    if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
        rm -f "$USER_HOME/.config/fastfetch/config.jsonc"
    fi
    ln -svf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc" || {
        echo "${RED}Failed to create symbolic link for fastfetch config${RC}"
        exit 1
    }
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d:  -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="$USER_HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ]; then
        echo "${YELLOW}Moving old bash config file to $USER_HOME/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
            echo "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo "${YELLOW}Linking new bash config file...${RC}"
    ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
        echo "${RED}Failed to create symbolic link for .bashrc${RC}"
        exit 1
    }
    ln -svf "$GITPATH/starship.toml" "$USER_HOME/.config/starship.toml" || {
        echo "${RED}Failed to create symbolic link for starship.toml${RC}"
        exit 1
    }
}

checkEnv
installStarshipAndFzf
installZoxide
create_fastfetch_config

if linkConfig; then
    echo "${GREEN}Done!\nRestart your shell to see the changes.${RC}"
else
    echo "${RED}Something went wrong!${RC}"
fi
