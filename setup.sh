#!/bin/bash
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
settings_only=0
set_default_shell=0
dry_run=0
packages_file=''
while [ "$#" -gt 0 ]; do
    case "$1" in
        --settings-only) settings_only=1 ;;
        --set-default-shell) set_default_shell=1 ;;
        --dry-run) dry_run=1 ;;
        --packages)
            [ "$#" -ge 2 ] || { echo '--packages requires a Brewfile path' >&2; exit 2; }
            packages_file="$2"; shift ;;
        --help) echo 'Usage: setup.sh [--settings-only] [--set-default-shell] [--dry-run] [--packages FILE]'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
if [ "$settings_only" -eq 1 ] && [ -n "$packages_file" ]; then
    echo '--packages cannot be combined with --settings-only' >&2; exit 2
fi
os="$(platform)"
if [ -n "$packages_file" ] && [ ! -f "$packages_file" ]; then
    echo "Package file not found: $packages_file" >&2; exit 2
fi
if [ "$dry_run" -eq 1 ]; then
    echo "Platform: $os"
    echo 'Preserve existing shell/Git settings and terminal preferences in backups/.'
    [ "$settings_only" -eq 1 ] || echo 'Install starter packages, Oh My Zsh, plugins and Powerlevel10k.'
    echo 'Deploy portable zsh configuration, prompt and saved Git preferences.'
    [ "$os" != macos ] || echo 'Install iTerm2 if needed and import saved preferences.'
    [ -z "$packages_file" ] || echo "Also install optional packages from $packages_file"
    [ "$set_default_shell" -eq 0 ] || echo 'Change the login shell to zsh.'
    exit 0
fi
# Snapshot before installers or preference imports can modify existing settings.
new_snapshot 'Target settings before setup'
for name in .zshrc .zprofile .zshenv .zlogin .bash_profile .bashrc .p10k.zsh .gitconfig .zshrc.portable .zshrc.local; do
    save_home_file "$name"
done
if [ "$os" = macos ]; then
    defaults export com.googlecode.iterm2 "$snapshot_dir/iterm2.plist" >/dev/null 2>&1 || true
fi
printf 'Existing settings preserved in %s\n' "$snapshot_dir"
if [ "$settings_only" -eq 0 ]; then
    if [ "$os" = macos ]; then
        bash "$repo_dir/macos/brew.sh" "$repo_dir/macos/dotfiles/.Brewfile"
        init_brew
        if [ ! -d /Applications/iTerm.app ] && [ ! -d "$HOME/Applications/iTerm.app" ]; then
            brew install --cask iterm2
        fi
    else
        bash "$repo_dir/linux/etc.sh"
        bash "$repo_dir/linux/homebrew.sh" "$repo_dir/linux/dotfiles/.Brewfile"
        init_brew
    fi
    bash "$repo_dir/$os/oh-my-zsh.sh"
    if [ -n "$packages_file" ]; then
        brew bundle --file "$packages_file"
    fi
elif [ -n "$packages_file" ]; then
    echo '--packages cannot be combined with --settings-only' >&2; exit 2
fi
deploy_file "$repo_dir/common/.zshrc" "$HOME/.zshrc"
if [ -f "$repo_dir/$os/dotfiles/.p10k.zsh" ]; then
    deploy_file "$repo_dir/$os/dotfiles/.p10k.zsh" "$HOME/.p10k.zsh"
fi
if [ -f "$repo_dir/common/.zshrc.portable" ]; then
    deploy_file "$repo_dir/common/.zshrc.portable" "$HOME/.zshrc.portable"
fi
if [ -s "$repo_dir/common/gitconfig" ]; then
    # Read keys separately to preserve whitespace/newlines in values.
    while IFS= read -r key; do
        value="$(git config --file "$repo_dir/common/gitconfig" --get "$key")"
        git config --global "$key" "$value"
    done < <(git config --file "$repo_dir/common/gitconfig" --name-only --list)
fi
if [ "$os" = macos ]; then
    bash "$repo_dir/macos/iterm2.sh"
fi
if [ "$set_default_shell" -eq 1 ]; then
    shell_path="$(command -v zsh)"
    if ! grep -Fxq "$shell_path" /etc/shells; then
        printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$shell_path"
fi
echo 'Setup complete. Open a new terminal or run: exec zsh -l'
echo 'Machine-specific tools belong in ~/.zshrc.local; portable additions belong in ~/.zshrc.portable.'
