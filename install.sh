#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$DOTFILES_DIR/manifest.txt"
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

log()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

need ln
need mkdir
need mv
need readlink
need awk

mkdir -p "$BACKUP_DIR"

link_one() {
  local src="$1"
  local dst="$2"
  dst="${dst/#\~/$HOME}"

  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      log "OK   $dst already linked"
      return 0
    fi
    log "BACK $dst -> $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR$(dirname "$dst")"
    mv "$dst" "$BACKUP_DIR$dst"
  fi

  log "LINK $dst -> $src"
  ln -s "$src" "$dst"
}

log "Dotfiles: $DOTFILES_DIR"
log "Backups:  $BACKUP_DIR"

[ -f "$MANIFEST" ] || { echo "Missing manifest: $MANIFEST" >&2; exit 1; }

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  src_rel="$(echo "$line" | awk '{print $1}')"
  dst="$(echo "$line" | awk '{print $2}')"

  if [ -z "${src_rel:-}" ] || [ -z "${dst:-}" ]; then
    warn "Skipping malformed line: $line"
    continue
  fi

  src="$DOTFILES_DIR/$src_rel"
  if [ ! -e "$src" ]; then
    warn "Source missing, skipping: $src_rel"
    continue
  fi

  link_one "$src" "$dst"
done < "$MANIFEST"

log "Done. Apply now: exec zsh"
