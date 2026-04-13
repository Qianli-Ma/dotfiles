#!/bin/bash

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
settings_dir="$dir/iterm2"
settings_file="$settings_dir/com.googlecode.iterm2.plist"

if [ -f "$settings_file" ]; then
    defaults import com.googlecode.iterm2 "$settings_file"
    echo "Applied iTerm2 preferences from $settings_file"
else
    echo "No repo-managed iTerm2 preferences were found in $settings_file. Skipping iTerm2 preference import."
fi
