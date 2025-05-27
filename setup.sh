#!/bin/bash

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install git via Homebrew and prioritize it over system git
if ! command -v "/opt/homebrew/bin/git" &> /dev/null; then
    echo "Installing Git..."
    brew install git
    if ! grep -q "/opt/homebrew/bin" "$HOME/.zprofile"; then
        echo "export PATH=\"/opt/homebrew/bin:\$PATH\"" >> "$HOME/.zprofile"
        export PATH="/opt/homebrew/bin:$PATH"
    fi
fi

# Configure SSH for Git authentication
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "=== Setting up SSH for GitHub ==="
    read -p "Enter your GitHub email: " git_email
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$git_email" -f "$HOME/.ssh/id_ed25519" -N ""
    eval "$(ssh-agent -s)"
    ssh-add "$HOME/.ssh/id_ed25519"
    if ! grep -q "ssh-agent" "$HOME/.zprofile"; then
        echo 'eval "$(ssh-agent -s)"' >> "$HOME/.zprofile"
        echo "ssh-add \"$HOME/.ssh/id_ed25519\" &> /dev/null" >> "$HOME/.zprofile"
    fi
    echo ""
    echo "=== SSH Public Key ==="
    echo "Copy the key below and add it to GitHub (https://github.com/settings/keys):"
    echo "---------------------"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo "---------------------"
    echo "After adding the key to GitHub, press Enter to continue."
    read -p ""
    echo "=== SSH Setup Complete ==="
fi

# Configure Git user settings
if ! git config --global user.email &> /dev/null; then
    echo "Configuring Git user settings..."
    git config --global user.name "TableGamesDealer"
    git config --global user.email "$git_email"
fi

# Update the setup repository if it has a valid Git history
SETUP_DIR="$HOME/setup"
if [ -d "$SETUP_DIR/.git" ] && git -C "$SETUP_DIR" rev-parse --verify main >/dev/null 2>&1; then
    echo "Updating setup repository..."
    cd "$SETUP_DIR"
    git pull origin main
    cd -
fi

# Install GitHub CLI via Brew and configure SSH authentication
if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    brew install gh
fi

# Check if gh is authenticated, configure SSH if not
if ! gh auth status &> /dev/null; then
    echo "=== Setting up GitHub CLI authentication with existing SSH key ==="
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        echo "Using existing SSH key for GitHub CLI authentication..."
        # Ensure the SSH agent is running and key is added
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519" &> /dev/null
        # Verify SSH key is accessible
        echo "Verifying SSH key with GitHub..."
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo "SSH key is valid for GitHub."
            # Perform initial GitHub CLI authentication
            echo "Performing initial GitHub CLI authentication..."
            echo "Please follow the prompts to authenticate (select 'GitHub.com', 'SSH' protocol, and 'Login with a web browser' for simplicity)."
            gh auth login --hostname github.com --git-protocol ssh
            if gh auth status &> /dev/null; then
                echo "Initial GitHub CLI authentication successful."
                # Attempt to add SSH key to GitHub (will skip if already exists)
                echo "Ensuring SSH key is added to GitHub for CLI..."
                gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "Mac-Setup-Key-$(date +%F)" --type authentication || echo "SSH key already exists or addition failed (continuing)."
                # Set SSH as the preferred protocol
                gh config set git_protocol ssh
                echo "GitHub CLI configured to use SSH."
            else
                echo "Initial GitHub CLI authentication failed."
                echo "Please manually authenticate with 'gh auth login' or set GH_TOKEN."
                echo "To set GH_TOKEN, create a token at https://github.com/settings/tokens with 'repo' and 'admin:public_key' scopes."
                echo "Then run: export GH_TOKEN=your_token"
                exit 1
            fi
        else
            echo "SSH key verification failed. Check if the key is added to GitHub: https://github.com/settings/keys"
            echo "Current SSH public key:"
            echo "---------------------"
            cat "$HOME/.ssh/id_ed25519.pub"
            echo "---------------------"
            echo "After adding the key to GitHub, press Enter to retry authentication."
            read -p ""
            if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                echo "SSH key is now valid. Performing initial GitHub CLI authentication..."
                gh auth login --hostname github.com --git-protocol ssh
                if gh auth status &> /dev/null; then
                    echo "Initial GitHub CLI authentication successful."
                    echo "Ensuring SSH key is added to GitHub for CLI..."
                    gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "Mac-Setup-Key-$(date +%F)" --type authentication || echo "SSH key already exists or addition failed (continuing)."
                    gh config set git_protocol ssh
                    echo "GitHub CLI configured to use SSH."
                else
                    echo "Initial GitHub CLI authentication failed."
                    echo "Please manually authenticate with 'gh auth login' or set GH_TOKEN."
                    exit 1
                fi
            else
                echo "SSH authentication still failed. Please manually authenticate with 'gh auth login'."
                exit 1
            fi
        fi
    else
        echo "No SSH key found. Running 'gh auth login' for interactive authentication..."
        gh auth login
        if gh auth status &> /dev/null; then
            echo "GitHub CLI authentication successful."
        else
            echo "GitHub CLI authentication failed."
            echo "Please manually authenticate with 'gh auth login'."
            exit 1
        fi
    fi
    echo "=== GitHub CLI Setup Complete ==="
fi

# Install Rust via rustup
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Install Rust LSP via rustup
if ! command -v rust-analyzer &> /dev/null; then
    echo "Installing Rust LSP via rustup..."
    rustup component add rust-analyzer clippy rust-docs
fi

# Install Cargo-Update
if ! command -v cargo-install-update &> /dev/null; then
    echo "Installing Cargo-Update via Cargo"
    cargo install cargo-update
fi

# Install Cargo-Audit
if ! command -v cargo-audit &> /dev/null; then
    echo "Installing cargo-audit..."
    cargo install cargo-audit --locked
fi

# Install Cargo-Deny
if ! command -v cargo-deny &> /dev/null; then
    echo "Installing cargo-deny..."
    cargo install cargo-deny --locked
fi

# Install cmake if not installed (required for some cargo packages like gitui)
if ! command -v cmake &> /dev/null; then
    echo "Installing cmake..."
    brew install cmake
fi

# Install LLVM (includes clangd) via Homebrew and prioritize it
if ! command -v "/opt/homebrew/opt/llvm/bin/clangd" &> /dev/null; then
    echo "Installing LLVM (includes clangd)..."
    brew install llvm
    if ! grep -q "/opt/homebrew/opt/llvm/bin" "$HOME/.zprofile"; then
        echo "export PATH=\"/opt/homebrew/opt/llvm/bin:\$PATH\"" >> "$HOME/.zprofile"
        export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    fi
fi

# Install WezTerm if not installed Pricing
if ! command -v wezterm &> /dev/null; then
    echo "Installing WezTerm by brew..."
    brew install --cask wezterm
fi

# Install Helix if not installed
if ! command -v hx &> /dev/null; then
    echo "Installing Helix by brew..."
    brew install helix
fi

# Install Zellij if not installed
if ! command -v zellij &> /dev/null; then
    echo "Installing Zellij by cargo..."
    cargo install zellij --locked
fi

# Install Taplo if not installed
if ! command -v taplo &> /dev/null; then
    echo "Installing Taplo by cargo..."
    cargo install taplo-cli --locked --features lsp
fi

# Install Lua if not installed
if ! command -v lua &> /dev/null; then
    echo "Installing Lua by brew..."
    brew install lua
fi

# Install Lua LSP if not installed
if ! command -v lua-language-server &> /dev/null; then
    echo "Installing Lua LSP by brew..."
    brew install lua-language-server
fi

# Install Bash LSP if not installed
if ! command -v bash-language-server &> /dev/null; then
    echo "Installing Bash LSP by brew..."
    brew install bash-language-server
fi

# Install yazi via cargo
if ! command -v yazi &> /dev/null; then
    echo "Installing yazi..."
    cargo install --locked yazi-fm yazi-cli
fi

# Install fzf via brew
if ! command -v fzf &> /dev/null; then
    echo "Installing FZF..."
    brew install fzf
fi

# Install zoxide via cargo
if ! command -v zoxide &> /dev/null; then
    echo "Installing Zoxide..."
    cargo install zoxide --locked
fi

# Install eza via cargo
if ! command -v eza &> /dev/null; then
    echo "Installing eza..."
    cargo install eza --locked
fi

# Install bat via cargo
if ! command -v bat &> /dev/null; then
    echo "Installing bat..."
    cargo install bat --locked
fi

# Install ripgrep via cargo
if ! command -v rg &> /dev/null; then
    echo "Installing ripgrep..."
    cargo install ripgrep --locked
fi

# Install fd via cargo
if ! command -v fd &> /dev/null; then
    echo "Installing fd..."
    cargo install fd-find --locked
fi

# Install gitui via cargo
if ! command -v gitui &> /dev/null; then
    echo "Installing gitui..."
    cargo install gitui --locked
fi

# Install bottom via cargo
if ! command -v btm &> /dev/null; then
    echo "Installing bottom..."
    cargo install btm --locked
fi

# Install presenterm via cargo
if ! command -v btm &> /dev/null; then
    echo "Installing presenterm..."
    cargo install presenterm --locked
fi

# Install markdown-oxide via cargo
if ! command -v markdown-oxide &> /dev/null; then
    echo "Installing markdown-oxide..."
    cargo install --locked --git https://github.com/Feel-ix-343/markdown-oxide.git markdown-oxide
fi

# Install json lsp via brew
if ! command -v vscode-json-language-server &> /dev/null; then
    echo "Installing json lsp..."
    brew install vscode-langservers-extracted
fi

# Install yaml lsp via brew
if ! command -v yaml-language-server &> /dev/null; then
    echo "Installing yaml lsp..."
    brew install yaml-language-server
fi

# Install html lsp via brew
if ! command -v superhtml &> /dev/null; then
    echo "Installing html lsp..."
    brew install superhtml
fi

# Set Helix as default editor
if ! grep -q "EDITOR=hx" "$HOME/.zprofile"; then
    echo "Setting Helix as default editor..."
    echo "export EDITOR=hx" >> "$HOME/.zprofile"
    export EDITOR=hx
fi

# Set Helix as default visual
if ! grep -q "VISUAL=hx" "$HOME/.zprofile"; then
    echo "Setting Helix as default visual..."
    echo "export VISUAL=hx" >> "$HOME/.zprofile"
    export VISUAL=hx
fi

echo "Running update:"
sh update.sh
echo "Configuring configs:"
sh configure.sh
source "$HOME/.zprofile"
echo "Setup script completed!"
