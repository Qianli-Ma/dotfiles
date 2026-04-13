#!/bin/bash

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

update_git_repo() {
    local path="$1"

    if [ -d "$path/.git" ]; then
        git -C "$path" pull --ff-only
    fi
}

case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        echo "Running on macOS"

        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        brew update
        brew upgrade
        brew upgrade --cask
        brew cleanup
        if brew help prune >/dev/null 2>&1; then
            brew prune
        fi
        brew bundle dump --force --file "$dir/macos/dotfiles/.Brewfile"

        update_git_repo "$HOME/.oh-my-zsh"
        update_git_repo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
        update_git_repo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-apple-touchbar"
        update_git_repo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions"
        update_git_repo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
        update_git_repo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

        [ -f "$HOME/.bash-profile" ] && cp "$HOME/.bash-profile" "$dir/macos/dotfiles/"
        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$dir/macos/dotfiles/"

        mkdir -p "$dir/macos/iterm2"
        if defaults export com.googlecode.iterm2 - >/dev/null 2>&1; then
            defaults export com.googlecode.iterm2 "$dir/macos/iterm2/com.googlecode.iterm2.plist"
        fi

        git add "$dir/macos/dotfiles/.Brewfile" \
            "$dir/macos/dotfiles/.zshrc" \
            "$dir/macos/dotfiles/.bash-profile" \
            "$dir/macos/iterm2/com.googlecode.iterm2.plist"
        git commit -m "autoupdate"
        git push
        exit 0
    ;;
    linux*)   echo "LINUX" ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac
