#!/bin/bash

set -Eeuo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
settings_dir="$dir/iterm2"
settings_file="$settings_dir/com.googlecode.iterm2.plist"

color_enabled=0
if [ -t 1 ]; then
    color_enabled=1
fi

if [ "$color_enabled" -eq 1 ]; then
    c_reset=$'\033[0m'
    c_blue=$'\033[34m'
    c_yellow=$'\033[33m'
    c_red=$'\033[31m'
else
    c_reset=""
    c_blue=""
    c_yellow=""
    c_red=""
fi

current_step=0
total_steps=1

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

if [ -f "$settings_file" ]; then
    log_stage "Import iTerm2 preferences"
    run_cmd defaults import com.googlecode.iterm2 "$settings_file"
    log_info "Applied iTerm2 preferences from $settings_file"
else
    log_stage "Import iTerm2 preferences"
    log_info "No repo-managed iTerm2 preferences were found in $settings_file. Skipping iTerm2 preference import."
fi
