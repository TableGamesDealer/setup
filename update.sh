#!/bin/bash

echo "Running Brew Upgrade:"
brew update
brew upgrade --force

echo "Running RustUp Upgrade:"
rustup upgrade

echo "Runing Cargo install-update -a"
cargo install-update -a
