#!/bin/bash
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
settings_file="$dir/iterm2/com.googlecode.iterm2.plist"
if [ -f "$settings_file" ]; then
    defaults import com.googlecode.iterm2 "$settings_file"
    echo 'iTerm2 preferences imported. Quit and reopen iTerm2 to load them; quit it before setup to avoid preference conflicts.'
fi
