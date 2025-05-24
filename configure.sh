#!/bin/bash

# Exit on error
set -e

# Configuration
CONFIG_REPO_URL="https://github.com/TableGamesDealer/.config.git"
CONFIG_DIR="$HOME/.config"
CONFIG_FILES=(
    "home/wezterm.lua:wezterm.lua"
    "home/zprofile:.zprofile"
    "home/zshrc:.zshrc"
)

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create or verify symlink
create_symlink() {
    local source_file="$1"
    local target_file="$2"
    if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
        echo "Symlink for $target_file already exists and is correct."
    elif [ -e "$target_file" ]; then
        echo "Backing up existing $target_file to $target_file.bak"
        mv "$target_file" "$target_file.bak"
        ln -sf "$source_file" "$target_file"
        echo "Created symlink: $target_file -> $source_file"
    else
        ln -sf "$source_file" "$target_file"
        echo "Created symlink: $target_file -> $source_file"
    fi
}

echo "Starting configuration setup..."

# Ensure git is installed
if ! command_exists git; then
    echo "Error: Git is not installed. Please run setup.sh first."
    exit 1
fi

# Clone or update the .config repository
if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Updating existing .config repository..."
    cd "$CONFIG_DIR"
    git pull origin main
    cd -
else
    echo "Cloning .config repository from $CONFIG_REPO_URL..."
    git clone "$CONFIG_REPO_URL" "$CONFIG_DIR"
fi

# Ensure the home directory exists in .config
mkdir -p "$CONFIG_DIR/home"

# Create symlinks for configuration files
echo "Setting up configuration symlinks..."
for config in "${CONFIG_FILES[@]}"; do
    IFS=':' read -r source_path target_name <<< "$config"
    source_file="$CONFIG_DIR/$source_path"
    target_file="$HOME/$target_name"
    if [ -f "$source_file" ]; then
        create_symlink "$source_file" "$target_file"
    else
        echo "Warning: $source_file not found in .config repository. Skipping."
    fi
done

# Source zprofile to apply changes in the current session
if [ -f "$HOME/.zprofile" ]; then
    echo "Sourcing $HOME/.zprofile to apply changes..."
    source "$HOME/.zprofile"
fi

echo "Configuration setup complete!"
