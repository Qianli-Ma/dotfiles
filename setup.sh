#!/bin/bash
# Autosetup script
if [["$OSTYPE" == "darwin"*]]; then
# MACOS system
# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# Install homebrew
./macos/brew.sh
fi