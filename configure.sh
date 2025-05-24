#!/bin/bash

# Exit on error
set -e

# Configuration
CONFIG_REPO_URL="git@github.com:TableGamesDealer/.config.git"
CONFIG_DIR="$HOME/.config"
REMOTE_NAME="origin"
CONFIG_FILES=(
    "home/wezterm.lua:.wezterm.lua"
    "home/zprofile:.zprofile"
    "home/zshrc:.zshrc"
    "home/gitconfig:.gitconfig"
)
BACKUP_DIR="$HOME/.config_backup_$(date +%F_%H-%M-%S)"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check internet connectivity
check_internet() {
    ping -c 1 github.com &> /dev/null
}

# Function to create or verify symlink
create_symlink() {
    local source_file="$1"
    local target_file="$2"
    if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
        echo "Symlink for $target_file already exists and is correct."
    elif [ -e "$target_file" ]; then
        echo "Backing up existing $target_file to $BACKUP_DIR..."
        mkdir -p "$BACKUP_DIR"
        cp -a "$target_file" "$BACKUP_DIR/$(basename "$target_file").bak" || {
            echo "Error: Failed to back up $target_file."
            exit 1
        }
        ln -sf "$source_file" "$target_file" || {
            echo "Error: Failed to create symlink $target_file -> $source_file."
            exit 1
        }
        echo "Created symlink: $target_file -> $source_file"
    else
        ln -sf "$source_file" "$target_file" || {
            echo "Error: Failed to create symlink $target_file -> $source_file."
            exit 1
        }
        echo "Created symlink: $target_file -> $source_file"
    fi
}

echo "Starting configuration setup..."

# Ensure git is installed
if ! command_exists git; then
    echo "Error: Git is not installed. Please run setup.sh first."
    exit 1
fi

# Ensure gh is installed
if ! command_exists gh; then
    echo "Error: GitHub CLI (gh) is not installed. Please run setup.sh first."
    exit 1
fi

# Check GitHub CLI authentication (skip if offline)
if check_internet; then
    if ! gh auth status &> /dev/null; then
        echo "Error: GitHub CLI is not authenticated. Running gh auth login..."
        gh auth login --hostname github.com --git-protocol ssh || {
            echo "Error: GitHub CLI authentication failed. Please manually run 'gh auth login'."
            exit 1
        }
    fi
else
    echo "Warning: Offline mode detected. Skipping GitHub CLI authentication check."
fi

# Check if repository exists on GitHub (skip if offline)
if check_internet; then
    if ! gh repo view TableGamesDealer/.config &> /dev/null; then
        echo "Error: Repository $CONFIG_REPO_URL does not exist or is inaccessible."
        echo "Please create the repository at https://github.com/TableGamesDealer/.config or check access rights."
        exit 1
    fi
else
    echo "Warning: Offline mode detected. Skipping GitHub repository check."
fi

# Determine the default branch (skip if offline)
if check_internet; then
    DEFAULT_BRANCH=$(gh repo view TableGamesDealer/.config --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")
    if [ -z "$DEFAULT_BRANCH" ]; then
        echo "Warning: Could not determine default branch. Defaulting to 'main'."
        DEFAULT_BRANCH="main"
    fi
else
    echo "Warning: Offline mode detected. Assuming default branch 'main'."
    DEFAULT_BRANCH="main"
fi

# Clone or update the .config repository
if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Checking .config repository configuration..."
    cd "$CONFIG_DIR"
    if git remote -v | grep -q "$REMOTE_NAME.*TableGamesDealer/.config"; then
        echo "Updating existing .config repository..."
        if check_internet; then
            git fetch "$REMOTE_NAME" && git merge --ff-only "$REMOTE_NAME/$DEFAULT_BRANCH" || {
                echo "Error: Failed to update from $CONFIG_REPO_URL. Check SSH access and repository status."
                exit 1
            }
        else
            echo "Warning: Offline mode detected. Skipping repository update."
        fi
    else
        echo "Warning: .config repository has incorrect or missing remote. Setting to $CONFIG_REPO_URL..."
        git remote add "$REMOTE_NAME" "$CONFIG_REPO_URL" || git remote set-url "$REMOTE_NAME" "$CONFIG_REPO_URL"
        if check_internet; then
            git fetch "$REMOTE_NAME" && git merge --ff-only "$REMOTE_NAME/$DEFAULT_BRANCH" || {
                echo "Error: Failed to update from $CONFIG_REPO_URL. Check SSH access and repository status."
                exit 1
            }
        else
            echo "Warning: Offline mode detected. Skipping remote fetch."
        fi
    fi
    cd -
else
    if check_internet; then
        echo "Cloning .config repository from $CONFIG_REPO_URL..."
        git clone -o "$REMOTE_NAME" "$CONFIG_REPO_URL" "$CONFIG_DIR" || {
            echo "SSH clone failed. Trying HTTPS..."
            CONFIG_REPO_URL="https://github.com/TableGamesDealer/.config.git"
            git clone -o "$REMOTE_NAME" "$CONFIG_REPO_URL" "$CONFIG_DIR" || {
                echo "Error: Failed to clone $CONFIG_REPO_URL."
                exit 1
            }
        }
    else
        echo "Error: Offline mode detected, and $CONFIG_DIR does not exist. Cannot proceed without .config repository."
        exit 1
    fi
fi

# Ensure the home directory exists in .config
mkdir -p "$CONFIG_DIR/home"

# Create gitconfig if missing
if [ ! -f "$CONFIG_DIR/home/gitconfig" ] || [ ! -s "$CONFIG_DIR/home/gitconfig" ]; then
    echo "Warning: $CONFIG_DIR/home/gitconfig not found or empty. Creating from existing ~/.gitconfig or default..."
    if [ -f "$HOME/.gitconfig" ] && [ -s "$HOME/.gitconfig" ]; then
        echo "Copying existing ~/.gitconfig to $CONFIG_DIR/home/gitconfig..."
        cp "$HOME/.gitconfig" "$CONFIG_DIR/home/gitconfig"
    else
        echo "Creating default $CONFIG_DIR/home/gitconfig..."
        cat <<EOF > "$CONFIG_DIR/home/gitconfig"
[user]
    name = TableGamesDealer
    email = your.email@example.com
[core]
    editor = hx
[init]
    defaultBranch = main
EOF
    fi
    # Commit the new gitconfig to the repository (if online)
    if check_internet; then
        cd "$CONFIG_DIR"
        git add home/gitconfig
        git commit -m "Add gitconfig for symlink" || echo "No changes to commit."
        git push "$REMOTE_NAME" "$DEFAULT_BRANCH" || {
            echo "Warning: Failed to push gitconfig to $CONFIG_REPO_URL. Continuing locally."
        }
        cd -
    else
        echo "Warning: Offline mode detected. $CONFIG_DIR/home/gitconfig created locally but not pushed."
    fi
fi

# Create symlinks for configuration files
echo "Setting up configuration symlinks..."
for config in "${CONFIG_FILES[@]}"; do
    IFS=':' read -r source_path target_name <<< "$config"
    source_file="$CONFIG_DIR/$source_path"
    target_file="$HOME/$target_name"
    echo "DEBUG: Checking source file: $source_file"
    if [ -f "$source_file" ] && [ -s "$source_file" ]; then
        echo "DEBUG: Source file exists, size: $(stat -f %z "$source_file") bytes"
        # Validate .gitconfig content
        if [ "$source_path" = "home/gitconfig" ]; then
            if ! grep -q "\[user\]" "$source_file" || ! grep -q "name =" "$source_file" || ! grep -q "email =" "$source_file"; then
                echo "Warning: $source_file is missing required [user] name or email settings. Skipping."
                continue
            fi
        fi
        create_symlink "$source_file" "$target_file"
    else
        echo "Warning: $source_file not found or empty in .config repository. Skipping."
        echo "DEBUG: Repository contents at $CONFIG_DIR/home:"
        ls -l "$CONFIG_DIR/home"
    fi
done

# Source zprofile or equivalent based on shell
if [ -f "$HOME/.zprofile" ]; then
    if [ -n "$ZSH_VERSION" ]; then
        echo "Sourcing $HOME/.zprofile to apply changes..."
        source "$HOME/.zprofile"
    elif [ -n "$BASH_VERSION" ]; then
        echo "Sourcing $HOME/.zprofile in Bash (ensure compatibility)..."
        source "$HOME/.zprofile" || echo "Warning: Failed to source .zprofile in Bash."
        # Create .bash_profile symlink if missing
        if [ ! -f "$HOME/.bash_profile" ]; then
            ln -sf "$HOME/.zprofile" "$HOME/.bash_profile"
            echo "Created symlink: $HOME/.bash_profile -> $HOME/.zprofile"
        fi
    else
        echo "Warning: Unknown shell detected. Skipping sourcing .zprofile."
    fi
else
    echo "Warning: $HOME/.zprofile not found. Skipping sourcing."
fi

echo "Configuration setup complete!"
