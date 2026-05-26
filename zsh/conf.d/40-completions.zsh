autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

# Note: do NOT run `terraform -install-autocomplete` here. It rewrites ~/.zshrc
# (which is a symlink back into this repo) on every shell start, creating a
# duplicate completion line. Terraform completion is already wired in zshrc.
