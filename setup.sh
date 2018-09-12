#!/bin/bash
# Install Powerline Fonts
cd ~ && git clone https://github.com/powerline/fonts.git --depth=1
cd ~/fonts && ./install.sh
rm ~/fonts
# Autosetup script
if [["$OSTYPE" == "darwin"*]]; then
    # MACOS system
    # Install homebrew
    ./macos/brew.sh
    # Setup oh-my-zsh
    ./macos/oh-my-zsh.sh
    cd ~/Library/Fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
    
fi