# Portable starter shell. Keep machine-specific additions in ~/.zshrc.local.
for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done
unset brew_path

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git extract)
for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/$plugin" ]] && plugins+=("$plugin")
done
unset plugin
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE
alias dir='ls -al'
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"
# This file is explicitly curated for use across machines and backed up.
[[ -r "$HOME/.zshrc.portable" ]] && source "$HOME/.zshrc.portable"
# This file stays on its own machine and is never copied into deployment settings.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
# A missing optional file must not make shell startup return failure.
true
