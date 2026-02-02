autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

# Terraform completion (best effort)
if command -v terraform >/dev/null 2>&1; then
  terraform -install-autocomplete >/dev/null 2>&1 || true
fi
