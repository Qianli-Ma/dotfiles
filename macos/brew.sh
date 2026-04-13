#!/bin/bash

set -euo pipefail

brewfile="${1:-}"

pick_fastest_url() {
    local best_url=""
    local best_time="999999"
    local url time_value

    for url in "$@"; do
        time_value="$(curl -L -o /dev/null -sS --connect-timeout 3 --max-time 8 -w '%{time_total}' "$url" 2>/dev/null || true)"

        if [ -n "$time_value" ] && awk "BEGIN { exit !($time_value < $best_time) }"; then
            best_time="$time_value"
            best_url="$url"
        fi
    done

    printf '%s\n' "$best_url"
}

configure_homebrew_mirror() {
    local brew_git_remote core_git_remote bottle_domain api_domain

    brew_git_remote="$(pick_fastest_url \
        "https://github.com/Homebrew/brew" \
        "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git" \
        "https://mirrors.ustc.edu.cn/brew.git")"

    core_git_remote="$(pick_fastest_url \
        "https://github.com/Homebrew/homebrew-core" \
        "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git" \
        "https://mirrors.ustc.edu.cn/homebrew-core.git")"

    bottle_domain="$(pick_fastest_url \
        "https://ghcr.io/v2/homebrew/core" \
        "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles" \
        "https://mirrors.ustc.edu.cn/homebrew-bottles")"

    api_domain="$(pick_fastest_url \
        "https://formulae.brew.sh/api" \
        "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api" \
        "https://mirrors.ustc.edu.cn/homebrew-bottles/api")"

    [ -n "$brew_git_remote" ] && export HOMEBREW_BREW_GIT_REMOTE="$brew_git_remote"
    [ -n "$core_git_remote" ] && export HOMEBREW_CORE_GIT_REMOTE="$core_git_remote"
    [ -n "$bottle_domain" ] && export HOMEBREW_BOTTLE_DOMAIN="$bottle_domain"
    [ -n "$api_domain" ] && export HOMEBREW_API_DOMAIN="$api_domain"
}

configure_homebrew_mirror

if ! command -v brew >/dev/null 2>&1; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

brew install zsh

if [ -n "$brewfile" ] && [ -f "$brewfile" ]; then
    brew bundle --file "$brewfile"
fi
