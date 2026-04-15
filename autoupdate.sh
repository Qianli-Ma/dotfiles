#!/bin/bash

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo_keepalive_pid=""
docker_patch_start="# >>> docker completion patch >>>"
docker_patch_end="# <<< docker completion patch <<<"

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

cleanup_sudo_keepalive() {
    if [ -n "${sudo_keepalive_pid:-}" ]; then
        kill "$sudo_keepalive_pid" >/dev/null 2>&1 || true
    fi
}

trap cleanup_sudo_keepalive EXIT

ensure_sudo_session() {
    if ! command -v sudo >/dev/null 2>&1; then
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi

    sudo -v

    if [ -z "${sudo_keepalive_pid:-}" ]; then
        while true; do
            sudo -n true >/dev/null 2>&1 || exit
            sleep 60
        done &
        sudo_keepalive_pid=$!
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

write_brewfile_from_leaves() {
    local file="$1"
    local tmp_file

    tmp_file="$(mktemp)"
    brew leaves | LC_ALL=C sort | sed 's/^/brew "/; s/$/"/' > "$tmp_file"
    mv "$tmp_file" "$file"
}

strip_managed_block() {
    local file="$1"
    local tmp_file

    [ -f "$file" ] || return 0

    tmp_file="$(mktemp)"
    awk -v start="$docker_patch_start" -v end="$docker_patch_end" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$file" > "$tmp_file"
    mv "$tmp_file" "$file"
}

discover_docker_completion_dirs() {
    local completion_dir

    if ! command -v zsh >/dev/null 2>&1; then
        return 0
    fi

    while IFS= read -r completion_dir; do
        [ -n "$completion_dir" ] || continue
        if [ -e "$completion_dir/_docker" ] || [ -L "$completion_dir/_docker" ]; then
            printf '%s\n' "$completion_dir"
        fi
    done < <(zsh -fc 'print -l $fpath' 2>/dev/null || true)
}

patch_zshrc_for_docker() {
    local file="$1"
    local source_name="$2"
    local tmp_file
    local inserted=0
    local docker_completion_dirs=()
    local docker_completion_dir

    [ -f "$file" ] || return 0

    strip_managed_block "$file"

    if command -v docker >/dev/null 2>&1; then
        return 0
    fi

    while IFS= read -r docker_completion_dir; do
        docker_completion_dirs+=("$docker_completion_dir")
    done < <(discover_docker_completion_dirs)

    [ "${#docker_completion_dirs[@]}" -gt 0 ] || return 0

    tmp_file="$(mktemp)"
    while IFS= read -r line; do
        if [ "$inserted" -eq 0 ] && [ "$line" = 'source $ZSH/oh-my-zsh.sh' ]; then
            printf '%s\n' "$docker_patch_start" >> "$tmp_file"
            printf '%s\n' "# Docker is not installed on this machine, so $source_name removed" >> "$tmp_file"
            printf '%s\n' '# Docker completion directories before Oh My Zsh initializes compinit.' >> "$tmp_file"
            for docker_completion_dir in "${docker_completion_dirs[@]}"; do
                printf 'fpath=(${fpath:#%s})\n' "$docker_completion_dir" >> "$tmp_file"
            done
            printf '%s\n\n' "$docker_patch_end" >> "$tmp_file"
            inserted=1
        fi
        printf '%s\n' "$line" >> "$tmp_file"
    done < "$file"
    mv "$tmp_file" "$file"
}

case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        echo "Running on macOS"
        ensure_sudo_session

        init_brew_shellenv
        configure_homebrew_mirror_env

        brew update
        brew upgrade
        brew upgrade --cask
        brew cleanup
        if brew help prune >/dev/null 2>&1; then
            brew prune
        fi
        write_brewfile_from_leaves "$dir/macos/dotfiles/.Brewfile"

        update_oh_my_zsh_components "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

        [ -f "$HOME/.bash-profile" ] && cp "$HOME/.bash-profile" "$dir/macos/dotfiles/"
        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$dir/macos/dotfiles/"
        patch_zshrc_for_docker "$dir/macos/dotfiles/.zshrc" "autoupdate"
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
        ensure_sudo_session

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
            run_nonblocking write_brewfile_from_leaves "$dir/linux/dotfiles/.Brewfile"
        fi

        update_oh_my_zsh_components "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$dir/linux/dotfiles/.zshrc"
        patch_zshrc_for_docker "$dir/linux/dotfiles/.zshrc" "autoupdate"
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
