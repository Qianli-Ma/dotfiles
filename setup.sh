#!/bin/bash
# Install Powerline Fonts
dir=$(pwd)
cd ~ && git clone https://github.com/powerline/fonts.git --depth=1
cd ~/fonts && ./install.sh
rm rf ~/fonts
# Autosetup script
case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        echo "Running on OSX"
        # MACOS system
        # Setup oh-my-zsh
        $dir/macos/oh-my-zsh.sh
        # Install homebrew
        $dir/macos/brew.sh
        cd ~/Library/Fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
        exit 0
    ;;
    linux*)   echo "LINUX" ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac