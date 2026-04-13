#!/bin/bash

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iterm_archive="$HOME/Downloads/iTerm2-latest.zip"
iterm_extract_dir="$HOME/Downloads/iTerm2-latest"
iterm_url="https://iterm2.com/downloads/stable/latest"
rerun_command="cd \"$dir\" && /bin/bash \"$dir/setup.sh\""

case "$OSTYPE" in
    solaris*) echo "SOLARIS" ;;
    darwin*)
        echo "Running on macOS"

        if [ ! -d "/Applications/iTerm.app" ]; then
            echo "iTerm2 is not installed yet."
            echo "Downloading the latest stable iTerm2 build to $iterm_archive"
            curl -L --fail --output "$iterm_archive" "$iterm_url"
            rm -rf "$iterm_extract_dir"
            mkdir -p "$iterm_extract_dir"
            ditto -x -k "$iterm_archive" "$iterm_extract_dir"
            mv "$iterm_extract_dir/iTerm.app" /Applications/iTerm.app
            open -a /Applications/iTerm.app --args --command="$rerun_command"
            echo "Opened iTerm2 and asked it to continue setup automatically."
            exit 0
        fi

        if [ "${TERM_PROGRAM:-}" != "iTerm.app" ]; then
            echo "Opening iTerm2 and continuing setup there."
            open -a /Applications/iTerm.app --args --command="$rerun_command"
            exit 0
        fi

        "$dir/macos/brew.sh" "$dir/macos/dotfiles/.Brewfile"
        "$dir/macos/oh-my-zsh.sh"
        rsync -a --exclude ".DS_Store" "$dir/macos/dotfiles/" "$HOME/"
        "$dir/macos/iterm2.sh"

        echo "Setup is complete. Please close and reopen iTerm2 so the new shell configuration and preferences are picked up."
        exit 0
    ;;
    linux*)
        echo "Running on Linux"
        "$dir/linux/oh-my-zsh.sh"
        rsync -a --exclude ".DS_Store" "$dir/linux/" "$HOME/"
        echo "Setup is complete. Open a new terminal session so the updated shell configuration is picked up."
    ;;
    bsd*)     echo "BSD" ;;
    msys*)    echo "WINDOWS" ;;
    *)        echo "unknown: $OSTYPE" ;;
esac
