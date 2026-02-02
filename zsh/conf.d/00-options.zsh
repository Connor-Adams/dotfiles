# Shell behavior + safety
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt NO_BG_NICE
setopt NO_HUP
setopt NO_BEEP

# Safer globbing (unmatched globs expand to nothing instead of error)
setopt NO_nomatch

# Default permissions for new files
umask 022

export HISTSIZE=20000
export SAVEHIST=20000
export HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
