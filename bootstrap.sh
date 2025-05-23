#!/bin/bash

# Clone the setup repository and run the setup script
REPO_URL="https://github.com/TableGamesDealer/setup.git"
SETUP_DIR="$HOME/setup"
SCRIPT_NAME="setup.sh"

if [ ! -d "$SETUP_DIR" ]; then
    echo "Cloning setup repository from $REPO_URL..."
    if ! command -v git &> /dev/null; then
        echo "Installing Git..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        brew install git
    fi
    git clone "$REPO_URL" "$SETUP_DIR"
fi

if [ -f "$SETUP_DIR/$SCRIPT_NAME" ]; then
    echo "Running setup script..."
    chmod +x "$SETUP_DIR/$SCRIPT_NAME"
    "$SETUP_DIR/$SCRIPT_NAME"
else
    echo "Error: $SCRIPT_NAME not found in $SETUP_DIR"
    exit 1
fi
