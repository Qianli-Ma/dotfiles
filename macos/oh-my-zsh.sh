#!/bin/bash

set -euo pipefail

export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
custom_dir="${ZSH_CUSTOM:-$ZSH/custom}"

clone_or_update() {
    local repo="$1"
    local destination="$2"

    if [ -d "$destination/.git" ]; then
        git -C "$destination" pull --ff-only
    else
        git clone "$repo" "$destination"
    fi
}

if [ ! -d "$ZSH" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

mkdir -p "$custom_dir/plugins" "$custom_dir/themes"

clone_or_update https://github.com/floor114/zsh-apple-touchbar "$custom_dir/plugins/zsh-apple-touchbar"
clone_or_update https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/plugins/zsh-autosuggestions"
clone_or_update https://github.com/zsh-users/zsh-completions "$custom_dir/plugins/zsh-completions"
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom_dir/plugins/zsh-syntax-highlighting"
clone_or_update https://github.com/romkatv/powerlevel10k.git "$custom_dir/themes/powerlevel10k"

if command -v brew >/dev/null 2>&1; then
    brew install --cask font-meslo-lg-nerd-font
fi
