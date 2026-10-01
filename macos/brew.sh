#!/bin/bash
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_brew
if ! command -v brew >/dev/null 2>&1; then
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl --fail --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    /bin/bash "$installer"
    init_brew
fi
brew bundle --file "${1:-$repo_dir/macos/dotfiles/.Brewfile}"
