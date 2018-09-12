#!/bin/sh
pwd='pwd'
case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        echo "Running on OSX"
        brew update
        brew upgrade
        brew cask upgrade
        brew missing
        brew cleanup
        brew prune
        brew bundle dump --force --global
        bash ~/.oh-my-zsh/tools/upgrade.sh
        git -C ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/ pull
        git -C ~/.oh-my-zsh/custom/plugins/zsh-apple-touchbar/ pull
        git -C ~/.oh-my-zsh/custom/plugins/zsh-completions/ pull
        git -C ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/ pull
        cp ~/.bash-profile macos/dotfiles/
        cp ~/.Brewfile macos/dotfiles/
        cp ~/.gitconfig macos/dotfiles/
        cp ~/.zshrc macos/dotfiles/
        exit 0
    ;;
    linux*)   echo "LINUX" ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac