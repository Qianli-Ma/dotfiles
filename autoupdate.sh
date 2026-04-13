#!/bin/bash

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

update_git_repo() {
    local path="$1"

    if [ -d "$path/.git" ]; then
        git -C "$path" pull --ff-only
    fi
}

update_oh_my_zsh_components() {
    local custom_dir="$1"
    local repo_path

    update_git_repo "$HOME/.oh-my-zsh"

    if [ -d "$custom_dir/plugins" ]; then
        for repo_path in "$custom_dir/plugins"/*; do
            [ -d "$repo_path" ] || continue
            update_git_repo "$repo_path"
        done
    fi

    if [ -d "$custom_dir/themes" ]; then
        for repo_path in "$custom_dir/themes"/*; do
            [ -d "$repo_path" ] || continue
            update_git_repo "$repo_path"
        done
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

        update_oh_my_zsh_components "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

        [ -f "$HOME/.bash-profile" ] && cp "$HOME/.bash-profile" "$dir/macos/dotfiles/"
        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$dir/macos/dotfiles/"
        [ -f "$HOME/.p10k.zsh" ] && cp "$HOME/.p10k.zsh" "$dir/macos/dotfiles/"

        mkdir -p "$dir/macos/iterm2"
        if defaults export com.googlecode.iterm2 - >/dev/null 2>&1; then
            defaults export com.googlecode.iterm2 "$dir/macos/iterm2/com.googlecode.iterm2.plist"
        fi

        git add "$dir/macos/dotfiles/.Brewfile" \
            "$dir/macos/dotfiles/.zshrc" \
            "$dir/macos/dotfiles/.p10k.zsh" \
            "$dir/macos/dotfiles/.bash-profile" \
            "$dir/macos/iterm2/com.googlecode.iterm2.plist"
        git commit -m "autoupdate"
        git push
        exit 0
    ;;
    linux*)
        echo "Running on Linux"

        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get upgrade -y
            sudo apt-get autoremove -y
            sudo apt-get autoclean -y
        fi

        update_oh_my_zsh_components "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$dir/linux/.zshrc"

        git add "$dir/linux/.zshrc"
        git commit -m "autoupdate"
        git push
        exit 0
    ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac
