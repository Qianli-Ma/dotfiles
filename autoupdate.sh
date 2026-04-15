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

run_nonblocking() {
    if ! "$@"; then
        echo "Non-fatal failure, continuing: $*"
    fi
}

init_brew_shellenv() {
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    fi
}

configure_homebrew_mirror_env() {
    export HOMEBREW_BOTTLE_DOMAIN="${HOMEBREW_BOTTLE_DOMAIN:-https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles}"
    export HOMEBREW_API_DOMAIN="${HOMEBREW_API_DOMAIN:-https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api}"
}

sanitize_linux_brewfile() {
    local file="$1"
    local tmp_file

    [ -f "$file" ] || return 0

    tmp_file="$(mktemp)"
    grep -v '^vscode "' "$file" > "$tmp_file" || true
    mv "$tmp_file" "$file"
}

case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        echo "Running on macOS"

        init_brew_shellenv
        configure_homebrew_mirror_env

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
        mkdir -p "$dir/linux/dotfiles"
        linux_git_add=("$dir/linux/dotfiles/.Brewfile" "$dir/linux/dotfiles/.zshrc")

        if command -v apt-get >/dev/null 2>&1; then
            run_nonblocking sudo apt-get update
            run_nonblocking sudo apt-get upgrade -y
            run_nonblocking sudo apt-get autoremove -y
            run_nonblocking sudo apt-get autoclean -y
        fi

        init_brew_shellenv
        if command -v brew >/dev/null 2>&1; then
            configure_homebrew_mirror_env
            run_nonblocking brew update
            run_nonblocking brew upgrade
            run_nonblocking brew cleanup
            run_nonblocking brew bundle dump --force --file "$dir/linux/dotfiles/.Brewfile"
            sanitize_linux_brewfile "$dir/linux/dotfiles/.Brewfile"
        fi

        update_oh_my_zsh_components "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$dir/linux/dotfiles/.zshrc"
        if [ -f "$HOME/.p10k.zsh" ]; then
            cp "$HOME/.p10k.zsh" "$dir/linux/dotfiles/.p10k.zsh"
            linux_git_add+=("$dir/linux/dotfiles/.p10k.zsh")
        fi

        git add "${linux_git_add[@]}"
        git commit -m "autoupdate"
        git push
        exit 0
    ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac
