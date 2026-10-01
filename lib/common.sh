#!/bin/bash
# Shared by the entry points; compatible with macOS Bash 3.2.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
platform() {
    case "${OSTYPE:-}" in
        darwin*) printf 'macos\n' ;;
        linux*) printf 'linux\n' ;;
        *) echo "Unsupported platform: ${OSTYPE:-unknown}" >&2; return 1 ;;
    esac
}
init_brew() {
    command -v brew >/dev/null 2>&1 && return 0
    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
        if [ -x "$candidate" ]; then
            eval "$("$candidate" shellenv)"
            return 0
        fi
    done
}
new_snapshot() {
    mkdir -p "$repo_dir/backups"
    snapshot_dir="$(mktemp -d "$repo_dir/backups/$(date +%Y%m%d-%H%M%S)-XXXXXX")"
    chmod 700 "$snapshot_dir"
    printf '%s\n' "$1" > "$snapshot_dir/purpose.txt"
}
save_home_file() {
    local relative="$1"
    if [ -e "$HOME/$relative" ] || [ -L "$HOME/$relative" ]; then
        mkdir -p "$snapshot_dir/home/$(dirname "$relative")"
        cp -pL "$HOME/$relative" "$snapshot_dir/home/$relative"
    fi
}

deploy_file() {
    local source_file="$1" destination="$2" temporary
    temporary="$(mktemp "${destination}.XXXXXX")"
    cp "$source_file" "$temporary"
    chmod 644 "$temporary"
    mv -f "$temporary" "$destination"
}
