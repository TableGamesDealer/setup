#!/bin/bash

# Exit on error
set -e

# Configuration
CONFIG_REPO_URL="git@github.com:TableGamesDealer/.config.git"
CONFIG_DIR="$HOME/.config"
REMOTE_NAME="main"
CONFIG_FILES=(
    "home/wezterm.lua:.wezterm.lua"
    "home/zprofile:.zprofile"
    "home/zshrc:.zshrc"
    "home/gitconfig:.gitconfig"
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

# Ensure gh is installed and authenticated
if ! command_exists gh; then
    echo "Error: GitHub CLI (gh) is not installed. Please run setup.sh first."
    exit 1
fi
if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI is not authenticated. Running gh auth login..."
    gh auth login --hostname github.com --git-protocol ssh
    if ! gh auth status &> /dev/null; then
        echo "Error: GitHub CLI authentication failed. Please manually run 'gh auth login'."
        exit 1
    fi
fi

# Check if repository exists on GitHub
if ! gh repo view TableGamesDealer/.config &> /dev/null; then
    echo "Error: Repository $CONFIG_REPO_URL does not exist or is inaccessible."
    echo "Please create the repository at https://github.com/TableGamesDealer/.config or check access rights."
    exit 1
fi

# Determine the default branch
DEFAULT_BRANCH=$(gh repo view TableGamesDealer/.config --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")
if [ -z "$DEFAULT_BRANCH" ]; then
    echo "Warning: Could not determine default branch. Defaulting to 'main'."
    DEFAULT_BRANCH="main"
fi

# Clone or update the .config repository
if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Checking .config repository configuration..."
    cd "$CONFIG_DIR"
    if git remote -v | grep -q "$REMOTE_NAME.*TableGamesDealer/.config"; then
        echo "Updating existing .config repository..."
        git fetch "$REMOTE_NAME" && git merge --ff-only "$REMOTE_NAME/$DEFAULT_BRANCH" || {
            echo "Error: Failed to update from $CONFIG_REPO_URL. Check SSH access and repository status."
            exit 1
        }
    else
        echo "Warning: .config repository has incorrect or missing remote. Setting to $CONFIG_REPO_URL..."
        git remote add "$REMOTE_NAME" "$CONFIG_REPO_URL" || git remote set-url "$REMOTE_NAME" "$CONFIG_REPO_URL"
        git fetch "$REMOTE_NAME" && git merge --ff-only "$REMOTE_NAME/$DEFAULT_BRANCH" || {
            echo "Error: Failed to update from $CONFIG_REPO_URL. Check SSH access and repository status."
            exit 1
        }
    fi
    cd -
else
    echo "Cloning .config repository from $CONFIG_REPO_URL..."
    git clone -o "$REMOTE_NAME" "$CONFIG_REPO_URL" "$CONFIG_DIR" || {
        echo "Error: Failed to clone $CONFIG_REPO_URL. Check SSH access and repository status."
        exit 1
    }
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
