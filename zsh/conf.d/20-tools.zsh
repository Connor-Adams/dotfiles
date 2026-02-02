# NVM (Homebrew install)
if command -v brew >/dev/null 2>&1; then
  local NVM_SH
  NVM_SH="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
  [[ -r "$NVM_SH" ]] && source "$NVM_SH"
fi

# direnv (zsh hook explicitly)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
