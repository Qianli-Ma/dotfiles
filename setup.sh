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
sudo_keepalive_pid=""
docker_patch_start="# >>> docker completion patch >>>"
docker_patch_end="# <<< docker completion patch <<<"

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

cleanup_sudo_keepalive() {
    if [ -n "${sudo_keepalive_pid:-}" ]; then
        kill "$sudo_keepalive_pid" >/dev/null 2>&1 || true
    fi
}

trap cleanup_sudo_keepalive EXIT

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

backup_zshrc() {
    if [ -f "$HOME/.zshrc" ]; then
        log_stage "Backup existing .zshrc"
        run_cmd cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
    fi
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

ensure_sudo_session() {
    local reason="$1"

    if ! command -v sudo >/dev/null 2>&1; then
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi

    log_stage "Authenticate sudo"
    log_info "$reason"
    run_cmd sudo -v

    if [ -z "${sudo_keepalive_pid:-}" ]; then
        while true; do
            sudo -n true >/dev/null 2>&1 || exit
            sleep 60
        done &
        sudo_keepalive_pid=$!
    fi
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

        total_steps=7
        log_stage "Platform detection: macOS"
        ensure_sudo_session "Administrator access will be reused during setup so you only need to authenticate once."
        log_stage "Homebrew bootstrap"
        run_cmd "$dir/macos/brew.sh" "$dir/macos/dotfiles/.Brewfile"
        log_stage "Oh My Zsh and plugins"
        run_cmd "$dir/macos/oh-my-zsh.sh"
        backup_zshrc
        log_stage "Copy macOS dotfiles"
        run_cmd rsync -a --exclude ".DS_Store" "$dir/macos/dotfiles/" "$HOME/"
        patch_zshrc_for_docker "$HOME/.zshrc" "setup"
        log_stage "Apply iTerm2 preferences"
        run_cmd "$dir/macos/iterm2.sh"

        finish_and_reload
    ;;
    linux*)
        total_steps=7
        log_stage "Platform detection: Linux"
        ensure_sudo_session "Administrator access will be reused during setup so apt and installer steps do not keep prompting."
        log_stage "Linux base packages and mirrors"
        run_cmd "$dir/linux/etc.sh"
        log_stage "Homebrew bootstrap"
        run_cmd "$dir/linux/homebrew.sh" "$dir/linux/dotfiles/.Brewfile"
        log_stage "Oh My Zsh and plugins"
        run_cmd "$dir/linux/oh-my-zsh.sh"
        backup_zshrc
        log_stage "Copy Linux dotfiles"
        run_cmd rsync -a --exclude ".DS_Store" "$dir/linux/dotfiles/" "$HOME/"
        patch_zshrc_for_docker "$HOME/.zshrc" "setup"

        finish_and_reload
    ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac
