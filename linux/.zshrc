# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Powerlevel10k is installed by setup but intentionally left inactive.
# To enable it later, set: ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_THEME=""

plugins=(git command-not-found extract zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

source "$ZSH/oh-my-zsh.sh"

alias dir="ls -al"

if command -v thefuck >/dev/null 2>&1; then
  eval "$(thefuck --alias --enable-experimental-instant-mode)"
fi
