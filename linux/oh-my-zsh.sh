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

install_linux_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y zsh git curl rsync fzf fonts-powerline
    else
        echo "apt-get is not available. On Debian-based systems, install: zsh git curl rsync fzf fonts-powerline"
        echo "Continuing with Oh My Zsh setup using whatever is already installed."
    fi
}

install_linux_packages

if [ ! -d "$ZSH" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

mkdir -p "$custom_dir/plugins" "$custom_dir/themes"

clone_or_update https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/plugins/zsh-autosuggestions"
clone_or_update https://github.com/zsh-users/zsh-completions "$custom_dir/plugins/zsh-completions"
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom_dir/plugins/zsh-syntax-highlighting"
clone_or_update https://github.com/romkatv/powerlevel10k.git "$custom_dir/themes/powerlevel10k"
