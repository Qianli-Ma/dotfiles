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

if command -v brew >/dev/null 2>&1; then
    log_stage "Install Meslo Nerd Font"
    run_cmd brew install --cask font-meslo-lg-nerd-font
else
    log_stage "Install Meslo Nerd Font"
    log_info "Homebrew is not available. Skipping Meslo Nerd Font installation."
fi
