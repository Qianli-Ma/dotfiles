#!/bin/bash
set -euo pipefail
zsh_dir="${ZSH:-$HOME/.oh-my-zsh}"
custom_dir="${ZSH_CUSTOM:-$zsh_dir/custom}"
if [ ! -d "$zsh_dir" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
fi
mkdir -p "$custom_dir/plugins" "$custom_dir/themes"
clone_if_missing() {
    if [ ! -d "$2" ]; then
        git clone "$1" "$2"
    fi
}
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git "$custom_dir/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-completions.git "$custom_dir/plugins/zsh-completions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom_dir/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/romkatv/powerlevel10k.git "$custom_dir/themes/powerlevel10k"
