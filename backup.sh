#!/bin/bash
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
include_packages=0
publish=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --packages) include_packages=1 ;;
        --publish) publish=1 ;;
        --help) echo 'Usage: backup.sh [--packages] [--publish]'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
os="$(platform)"
new_snapshot 'Source settings before update or deployment'
for name in .zshrc .zprofile .zshenv .zlogin .bash_profile .bashrc .p10k.zsh .gitconfig .zshrc.portable .zshrc.local; do
    save_home_file "$name"
done
mkdir -p "$repo_dir/common" "$repo_dir/$os/dotfiles"
# Raw shell startup files can contain secrets and machine-specific paths.
# Only explicitly portable additions and the prompt are exported for deployment.
if [ -f "$HOME/.p10k.zsh" ]; then
    cp "$HOME/.p10k.zsh" "$repo_dir/$os/dotfiles/.p10k.zsh"
fi
if [ -f "$HOME/.zshrc.portable" ]; then
    cp "$HOME/.zshrc.portable" "$repo_dir/common/.zshrc.portable"
else
    rm -f "$repo_dir/common/.zshrc.portable"
fi
# Export a small allowlist; never export credentials, includes or helper commands.
git_settings="$(mktemp)"
for key in user.name user.email init.defaultBranch pull.rebase fetch.prune color.ui push.default rerere.enabled merge.conflictstyle; do
    if value="$(git config --global --get "$key")"; then
        git config --file "$git_settings" "$key" "$value"
    fi
done
mv "$git_settings" "$repo_dir/common/gitconfig"
chmod 644 "$repo_dir/common/gitconfig"
if [ "$os" = macos ]; then
    mkdir -p "$repo_dir/macos/iterm2"
    if defaults export com.googlecode.iterm2 "$snapshot_dir/iterm2.plist" >/dev/null 2>&1; then
        cp "$snapshot_dir/iterm2.plist" "$repo_dir/macos/iterm2/com.googlecode.iterm2.plist"
    else
        echo 'No iTerm2 preferences available; existing deployment preferences kept.'
    fi
fi
if [ "$include_packages" -eq 1 ]; then
    init_brew
    if ! command -v brew >/dev/null 2>&1; then
        echo "Settings saved to $snapshot_dir; package inventory needs Homebrew." >&2
        exit 1
    fi
    # Generate atomically. Never replace the starter Brewfile.
    inventory="$(mktemp "$repo_dir/$os/.packages-XXXXXX")"
    if brew bundle dump --force --file "$inventory"; then
        mv "$inventory" "$repo_dir/$os/packages.Brewfile"
    else
        rm -f "$inventory"
        echo 'Package inventory failed; previous inventory kept.' >&2
        exit 1
    fi
fi
printf 'Local snapshot: %s\nPortable settings refreshed.\n' "$snapshot_dir"
if [ "$publish" -eq 1 ]; then
    paths=(common "$os/dotfiles" "$os/packages.Brewfile")
    [ "$os" != macos ] || paths+=(macos/iterm2)
    # Only include existing/previously tracked paths, and isolate unrelated staged work.
    selected=()
    for path in "${paths[@]}"; do
        if [ -e "$repo_dir/$path" ] || [ -n "$(git -C "$repo_dir" ls-files -- "$path")" ]; then
            selected+=("$path")
        fi
    done
    git -C "$repo_dir" add -A -- "${selected[@]}"
    if ! git -C "$repo_dir" diff --quiet HEAD -- "${selected[@]}"; then
        git -C "$repo_dir" commit --only -m 'Back up portable environment settings' -- "${selected[@]}"
    else
        echo 'Portable settings unchanged; no new commit needed.'
    fi
    # Still push when unchanged, so a previously failed push can be retried.
    git -C "$repo_dir" push
fi
