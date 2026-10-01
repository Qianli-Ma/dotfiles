#!/bin/bash
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
publish=0
include_packages=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --publish) publish=1 ;;
        --packages) include_packages=1 ;;
        --help) echo 'Usage: autoupdate.sh [--packages] [--publish]'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
set --
[ "$include_packages" -eq 0 ] || set -- "$@" --packages
[ "$publish" -eq 0 ] || set -- "$@" --publish
# Back up before any updates, including any requested remote backup.
bash "$repo_dir/backup.sh" "$@"
os="$(platform)"
failures=0
attempt() {
    if ! "$@"; then
        printf 'Update failed: %s\n' "$*" >&2
        failures=$((failures + 1))
    fi
}
if [ "$os" = linux ] && command -v apt-get >/dev/null 2>&1; then
    if sudo apt-get update; then
        attempt sudo apt-get upgrade -y
    else
        echo 'apt metadata refresh failed; skipping apt upgrade.' >&2
        failures=$((failures + 1))
    fi
fi
init_brew
if command -v brew >/dev/null 2>&1; then
    if brew update; then
        attempt brew upgrade
        # Keep old versions when upgrades fail, allowing recovery.
        [ "$failures" -ne 0 ] || attempt brew cleanup
    else
        echo 'Homebrew metadata refresh failed; skipping upgrades.' >&2
        failures=$((failures + 1))
    fi
fi
zsh_dir="${ZSH:-$HOME/.oh-my-zsh}"
custom_dir="${ZSH_CUSTOM:-$zsh_dir/custom}"
for path in "$zsh_dir" "$custom_dir"/plugins/* "$custom_dir"/themes/*; do
    if [ -e "$path/.git" ]; then
        attempt git -C "$path" pull --ff-only
    fi
done
if [ "$failures" -gt 0 ]; then
    echo "Backup completed; $failures update step(s) failed." >&2
    exit 1
fi
echo 'Backup and updates completed.'
