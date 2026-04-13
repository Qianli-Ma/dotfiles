#!/bin/bash

set -Eeuo pipefail

export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
custom_dir="${ZSH_CUSTOM:-$ZSH/custom}"

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

clone_or_update() {
    local repo="$1"
    local destination="$2"

    if [ -d "$destination/.git" ]; then
        run_cmd git -C "$destination" pull --ff-only
    else
        run_cmd git clone "$repo" "$destination"
    fi
}

configure_apt_mirror() {
    local codename temp_dir generated_sources

    if [ ! -f /etc/debian_version ]; then
        log_info "Not a Debian system. Skipping apt mirror selection."
        return 0
    fi

    if ! command -v netselect-apt >/dev/null 2>&1; then
        log_stage "Install netselect-apt"
        run_cmd sudo apt-get update
        run_cmd sudo apt-get install -y netselect-apt
    fi

    codename="$(. /etc/os-release 2>/dev/null && printf '%s' "${VERSION_CODENAME:-}")"
    if [ -z "$codename" ]; then
        log_info "Could not determine Debian codename. Leaving apt mirror configuration unchanged."
        return 0
    fi

    temp_dir="$(mktemp -d)"
    generated_sources="$temp_dir/sources.list"

    log_stage "Select Debian apt mirror"
    if (
        cd "$temp_dir" &&
        sudo netselect-apt -n "$codename"
    ) && [ -f "$generated_sources" ]; then
        run_cmd sudo cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)"
        run_cmd sudo cp "$generated_sources" /etc/apt/sources.list
    else
        log_info "netselect-apt did not produce a usable sources.list. Leaving the current apt mirror unchanged."
    fi

    run_cmd rm -rf "$temp_dir"
}

install_linux_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        configure_apt_mirror
        log_stage "Install Linux packages"
        run_cmd sudo apt-get update
        run_cmd sudo apt-get install -y zsh git curl rsync fzf fonts-powerline
    else
        log_info "apt-get is not available. On Debian-based systems, install: zsh git curl rsync fzf fonts-powerline"
        log_info "Continuing with Oh My Zsh setup using whatever is already installed."
        current_step=$((current_step + 1))
        printf '\n%s[stage %d/%d]%s %s\n' "$c_blue" "$current_step" "$total_steps" "$c_reset" "Install Linux packages"
        log_info "Skipped Linux package installation because apt-get is unavailable."
    fi
}

install_linux_packages

if [ ! -d "$ZSH" ]; then
    log_stage "Install Oh My Zsh"
    printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    log_stage "Install Oh My Zsh"
    log_info "Oh My Zsh is already installed. Skipping installation."
fi

log_stage "Prepare Oh My Zsh directories"
run_cmd mkdir -p "$custom_dir/plugins" "$custom_dir/themes"

log_stage "Install or update plugins and theme"
clone_or_update https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/plugins/zsh-autosuggestions"
clone_or_update https://github.com/zsh-users/zsh-completions "$custom_dir/plugins/zsh-completions"
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom_dir/plugins/zsh-syntax-highlighting"
clone_or_update https://github.com/romkatv/powerlevel10k.git "$custom_dir/themes/powerlevel10k"
