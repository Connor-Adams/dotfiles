#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prepend ~/.local/bin to PATH up front. Required because bootstrap runs in
# bash (not zsh), so it doesn't auto-source our zshrc's PATH wiring. Without
# this, `command -v claude` / `command -v uv` would return false on re-runs
# even when the binaries are already installed at ~/.local/bin/.
export PATH="$HOME/.local/bin:$PATH"

log()   { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;36m✓\033[0m  %s\n" "$*"; }
warn()  { printf "\033[1;33m!!\033[0m %s\n" "$*"; }

# ---- 1. Xcode Command Line Tools ----
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (a GUI installer will appear)..."
  xcode-select --install || true
  warn "Wait for the Xcode CLT installer to finish, then re-run bootstrap.sh."
  exit 0
fi
ok "Xcode CLT: $(xcode-select -p)"

# ---- 2. Homebrew ----
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
ok "Homebrew: $(command -v brew)"

# ---- 3. brew bundle ----
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  log "Running brew bundle (Brewfile)..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

# ---- 4. oh-my-zsh ----
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installing oh-my-zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  ok "oh-my-zsh already installed"
fi

# ---- 5. powerlevel10k ----
P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  log "Cloning powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  ok "powerlevel10k already cloned"
fi

# ---- 6. Symlink dotfiles ----
log "Linking dotfiles via install.sh..."
"$DOTFILES_DIR/install.sh"

# ---- 7. Claude Code CLI ----
if ! command -v claude >/dev/null 2>&1; then
  log "Installing Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
else
  ok "Claude Code already installed ($(claude --version 2>/dev/null | head -1))"
fi

# ---- 8. uv (Astral) ----
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv (Astral)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  ok "uv already installed ($(uv --version 2>/dev/null))"
fi

# ---- 9. MCP backends via uv ----
# macOS ships Python 3.9; kindex needs >=3.10, constrain needs >=3.12.
# Use the brew-installed python@3.14. `uv tool install --python` accepts a
# version selector and will fetch a managed interpreter if needed.
UV_PY="3.14"

# kindex: public PyPI package.
if uv tool list 2>/dev/null | grep -qE '^kindex '; then
  ok "kindex already installed via uv"
else
  log "Installing kindex[mcp] via uv (Python $UV_PY)..."
  uv tool install --python "$UV_PY" "kindex[mcp]" \
    || warn "uv tool install kindex[mcp] failed"
fi

# constrain: PRIVATE GitHub repo (jmcentire/constrain). Requires gh auth
# (HTTPS credential helper) or an SSH key registered with GitHub.
# The PyPI package named "constrain" is a different, unrelated tool — do
# NOT use it without the @ git+... source.
if uv tool list 2>/dev/null | grep -qE '^constrain '; then
  ok "constrain already installed via uv"
else
  log "Installing constrain[mcp] from private repo via uv (Python $UV_PY)..."
  uv tool install --python "$UV_PY" \
    "constrain[mcp] @ git+https://github.com/jmcentire/constrain.git" \
    || warn "constrain install failed (run 'gh auth login' first?)"
fi

# ---- 10. Register MCP servers with Claude Code ----
register_mcp_stdio() {
  local name="$1"; local binary="$2"
  if ! command -v "$binary" >/dev/null 2>&1; then
    warn "$binary not in PATH; skipping '$name' MCP registration"
    return
  fi
  claude mcp remove "$name" -s user >/dev/null 2>&1 || true
  claude mcp add    -s user "$name" -- "$binary" >/dev/null
  ok "MCP registered: $name -> $binary"
}

if command -v claude >/dev/null 2>&1; then
  log "Registering MCP servers at user scope..."
  register_mcp_stdio kindex kin-mcp
  register_mcp_stdio constrain constrain-mcp
  # serena: no separate install — uvx fetches on first run.
  claude mcp remove serena -s user >/dev/null 2>&1 || true
  claude mcp add    -s user serena -- uvx --from git+https://github.com/oraios/serena \
    serena start-mcp-server --context ide-assistant --open-web-dashboard False >/dev/null
  ok "MCP registered: serena -> uvx (oraios/serena)"
else
  warn "claude CLI not found; skipping MCP registration."
fi

# ---- 11. Conditional next-steps summary ----
echo
log "Bootstrap complete."

todo=()
n=1

# Default shell
if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
  todo+=("$((n++)). Make zsh the default shell:   chsh -s \"\$(command -v zsh)\"")
fi

# powerlevel10k prompt config
if [ ! -f "$HOME/.p10k.zsh" ]; then
  todo+=("$((n++)). Configure powerlevel10k:       p10k configure  (or just open a new shell)")
fi

# gh auth
if ! gh auth status >/dev/null 2>&1; then
  todo+=("$((n++)). Sign in to GitHub CLI:         gh auth login")
  if ! uv tool list 2>/dev/null | grep -qE '^constrain '; then
    todo+=("       (constrain pulls from a private repo and needs gh auth before it can install)")
  fi
fi

# Always-useful tips that depend on first-run state
if [ ! -d "$HOME/.dotfiles-backup" ] || [ "$(ls -A "$HOME/.dotfiles-backup" 2>/dev/null | wc -l)" -gt 0 ]; then
  # Likely the first full bootstrap if backups were created
  :
fi

# Always mention font + reload — they're easy to miss
todo+=("$((n++)). In iTerm2: Preferences > Profiles > Text -> font \"MesloLGS NF\"  (skip if already set)")
todo+=("$((n++)). Restart shell to pick up new PATH/config:   exec zsh")

if [ ${#todo[@]} -gt 0 ]; then
  echo
  echo "Manual steps remaining:"
  for step in "${todo[@]}"; do
    echo "   $step"
  done
fi
