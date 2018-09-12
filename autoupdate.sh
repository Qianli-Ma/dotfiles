#!/bin/sh
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
        exit 0
    ;;
    linux*)   echo "LINUX" ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac