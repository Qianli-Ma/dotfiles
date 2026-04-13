#!/bin/bash

set -Eeuo pipefail

brewfile="${1:-}"

color_enabled=0
if [ -t 1 ]; then
    color_enabled=1
fi

if [ "$color_enabled" -eq 1 ]; then
    c_reset=$'\033[0m'
    c_blue=$'\033[34m'
    c_green=$'\033[32m'
    c_yellow=$'\033[33m'
    c_red=$'\033[31m'
else
    c_reset=""
    c_blue=""
    c_green=""
    c_yellow=""
    c_red=""
fi

current_step=0
total_steps=4

log_stage() {
    current_step=$((current_step + 1))
    printf '\n%s[stage %d/%d]%s %s\n' "$c_blue" "$current_step" "$total_steps" "$c_reset" "$1"
}

run_cmd() {
    printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" "$*"
    "$@"
}

log_info() {
    printf '%s[info]%s %s\n' "$c_blue" "$c_reset" "$1"
}

log_error() {
    printf '%s[error]%s %s\n' "$c_red" "$c_reset" "$1"
}

wait_for_user() {
    local prompt="$1"
    printf '%s' "$prompt"
    read -r _
}

handle_error() {
    local exit_code="$1"
    local line_no="$2"
    local command="${3:-unknown}"
    echo
    log_error "Command failed at line $line_no: $command"
    log_error "Exit code: $exit_code"
    wait_for_user "[wait] Review the failure, then press Enter to exit this stage..."
    exit "$exit_code"
}

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

ensure_sudo_access() {
    log_info "Homebrew installation needs administrator access."
    run_cmd sudo -v
}

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

    log_info "HOMEBREW_BREW_GIT_REMOTE=${HOMEBREW_BREW_GIT_REMOTE:-unset}"
    log_info "HOMEBREW_CORE_GIT_REMOTE=${HOMEBREW_CORE_GIT_REMOTE:-unset}"
    log_info "HOMEBREW_BOTTLE_DOMAIN=${HOMEBREW_BOTTLE_DOMAIN:-unset}"
    log_info "HOMEBREW_API_DOMAIN=${HOMEBREW_API_DOMAIN:-unset}"
}

log_stage "Configure Homebrew mirrors"
configure_homebrew_mirror

if ! command -v brew >/dev/null 2>&1; then
    log_stage "Install Homebrew"
    ensure_sudo_access
    printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    current_step=$((current_step + 1))
    printf '\n%s[stage %d/%d]%s %s\n' "$c_blue" "$current_step" "$total_steps" "$c_reset" "Install Homebrew"
    log_info "Homebrew is already installed. Skipping installation."
fi

log_stage "Initialize Homebrew shell environment"
if [ -x /opt/homebrew/bin/brew ]; then
    printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" 'eval "$(/usr/local/bin/brew shellenv)"'
    eval "$(/usr/local/bin/brew shellenv)"
fi

log_stage "Install zsh"
run_cmd brew install zsh

if [ -n "$brewfile" ] && [ -f "$brewfile" ]; then
    current_step=$((current_step + 1))
    printf '\n%s[stage %d/%d]%s %s\n' "$c_blue" "$current_step" "$total_steps" "$c_reset" "Install Brewfile packages"
    run_cmd brew bundle --file "$brewfile"
fi
