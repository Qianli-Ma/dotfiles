#!/bin/bash

set -Eeuo pipefail

export PATH="/snap/bin:$PATH"

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
total_steps=3

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

wait_for_apt_to_finish() {
    local waited=0
    local lock_file holder_pids holder_pid

    if ! command -v apt-get >/dev/null 2>&1; then
        return 0
    fi

    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
        || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
        || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
        || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        if [ "$waited" -eq 0 ]; then
            log_info "Another apt operation is running. Waiting for it to finish before continuing."
            waited=1
        fi

        for lock_file in \
            /var/lib/dpkg/lock-frontend \
            /var/lib/dpkg/lock \
            /var/lib/apt/lists/lock \
            /var/cache/apt/archives/lock; do
            holder_pids="$(sudo fuser "$lock_file" 2>/dev/null || true)"
            if [ -n "$holder_pids" ]; then
                log_info "Lock file in use: $lock_file"
                for holder_pid in $holder_pids; do
                    ps -p "$holder_pid" -o pid=,ppid=,user=,etime=,command= 2>/dev/null || true
                done
            fi
        done

        sleep 5
    done
}

run_mirrorselect() {
    local release_codename="${1:-}"
    local mirror_cmd=("/snap/bin/mirrorselect")
    local output country_code

    if [ -n "$release_codename" ]; then
        mirror_cmd+=(--release "$release_codename")
    fi

    printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" "${mirror_cmd[*]}"
    if output="$("${mirror_cmd[@]}" 2>&1)"; then
        printf '%s\n' "$output"
        return 0
    fi

    printf '%s\n' "$output"

    if printf '%s' "$output" | grep -qi "specify one manually using --country"; then
        printf '[wait] Enter a 2-letter country code for mirrorselect (for example: US, CN, DE): '
        read -r country_code
        if [ -z "$country_code" ]; then
            log_error "No country code entered. Cannot continue mirror selection."
            return 1
        fi

        mirror_cmd=("/snap/bin/mirrorselect" --country "$country_code")
        if [ -n "$release_codename" ]; then
            mirror_cmd+=(--release "$release_codename")
        fi

        printf '%s[run]%s %s\n' "$c_yellow" "$c_reset" "${mirror_cmd[*]}"
        "${mirror_cmd[@]}"
        return 0
    fi

    return 1
}

configure_apt_mirror() {
    local release_codename

    if ! command -v apt-get >/dev/null 2>&1; then
        log_info "apt-get is not available. Skipping Linux package mirror selection."
        current_step=$((current_step + 1))
        printf '\n%s[stage %d/%d]%s %s\n' "$c_blue" "$current_step" "$total_steps" "$c_reset" "Configure apt mirror"
        log_info "Skipped apt mirror configuration because apt-get is unavailable."
        return 0
    fi

    if ! command -v snap >/dev/null 2>&1; then
        log_stage "Install snapd"
        wait_for_apt_to_finish
        run_cmd sudo apt-get update
        wait_for_apt_to_finish
        run_cmd sudo apt-get install -y snapd
    else
        log_stage "Install snapd"
        log_info "snapd is already installed. Skipping installation."
    fi

    if ! snap list mirrorselect >/dev/null 2>&1; then
        log_stage "Configure apt mirror"
        run_cmd sudo snap install mirrorselect
    else
        log_stage "Configure apt mirror"
        log_info "mirrorselect is already installed."
    fi

    release_codename="$(. /etc/os-release 2>/dev/null && printf '%s' "${VERSION_CODENAME:-}")"
    run_mirrorselect "$release_codename"
}

install_linux_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        log_stage "Install Linux packages"
        wait_for_apt_to_finish
        run_cmd sudo apt-get update
        wait_for_apt_to_finish
        run_cmd sudo apt-get install -y zsh git curl rsync fonts-powerline
    else
        log_stage "Install Linux packages"
        log_info "apt-get is not available. On Debian-based systems, install: zsh git curl rsync fonts-powerline"
    fi
}

configure_apt_mirror
install_linux_packages
