#!/bin/bash

set -Eeuo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iterm_archive="$HOME/Downloads/iTerm2-latest.zip"
iterm_extract_dir="$HOME/Downloads/iTerm2-latest"
iterm_url="https://iterm2.com/downloads/stable/latest"
rerun_command="cd \"$dir\" && /bin/bash \"$dir/setup.sh\""

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
total_steps=0

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

log_success() {
    printf '%s[success]%s %s\n' "$c_green" "$c_reset" "$1"
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
    wait_for_user "[wait] Fix anything you need, then press Enter to exit..."
    exit "$exit_code"
}

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

close_current_terminal() {
    case "${TERM_PROGRAM:-}" in
        Apple_Terminal)
            osascript -e 'tell application "Terminal" to close front window' >/dev/null 2>&1 || true
        ;;
        WarpTerminal)
            osascript -e 'tell application "Warp" to close front window' >/dev/null 2>&1 || true
        ;;
    esac
}

finish_and_reload() {
    log_stage "Complete"
    log_success "Setup finished successfully."
    wait_for_user "[wait] Press Enter to reload into zsh now, or Ctrl-C to stay in the current shell..."
    exec zsh -l
}

case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        if [ ! -d "/Applications/iTerm.app" ]; then
            total_steps=2
            log_stage "Platform detection: macOS"
            log_stage "iTerm2 installation"
            log_info "iTerm2 is not installed yet."
            run_cmd curl -L --fail --output "$iterm_archive" "$iterm_url"
            run_cmd rm -rf "$iterm_extract_dir"
            run_cmd mkdir -p "$iterm_extract_dir"
            run_cmd ditto -x -k "$iterm_archive" "$iterm_extract_dir"
            run_cmd mv "$iterm_extract_dir/iTerm.app" /Applications/iTerm.app
            run_cmd open -a /Applications/iTerm.app --args --command="$rerun_command"
            close_current_terminal
            log_info "Opened iTerm2 and asked it to continue setup automatically."
            exit 0
        fi

        if [ "${TERM_PROGRAM:-}" != "iTerm.app" ]; then
            total_steps=2
            log_stage "Platform detection: macOS"
            log_stage "iTerm2 handoff"
            log_info "Current terminal is ${TERM_PROGRAM:-unknown}; switching to iTerm2."
            run_cmd open -a /Applications/iTerm.app --args --command="$rerun_command"
            close_current_terminal
            exit 0
        fi

        total_steps=6
        log_stage "Platform detection: macOS"
        log_stage "Homebrew bootstrap"
        run_cmd "$dir/macos/brew.sh" "$dir/macos/dotfiles/.Brewfile"
        log_stage "Oh My Zsh and plugins"
        run_cmd "$dir/macos/oh-my-zsh.sh"
        log_stage "Copy macOS dotfiles"
        run_cmd rsync -a --exclude ".DS_Store" "$dir/macos/dotfiles/" "$HOME/"
        log_stage "Apply iTerm2 preferences"
        run_cmd "$dir/macos/iterm2.sh"

        finish_and_reload
    ;;
    linux*)
        total_steps=4
        log_stage "Platform detection: Linux"
        log_stage "Oh My Zsh, packages, and plugins"
        run_cmd "$dir/linux/oh-my-zsh.sh"
        log_stage "Copy Linux dotfiles"
        run_cmd rsync -a --exclude ".DS_Store" "$dir/linux/" "$HOME/"

        finish_and_reload
    ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac
