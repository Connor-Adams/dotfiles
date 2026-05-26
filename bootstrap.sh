#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$*"; }

# ---- 1. Xcode Command Line Tools ----
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (a GUI installer will appear)..."
  xcode-select --install || true
  warn "Wait for Xcode CLT installer to finish, then re-run bootstrap.sh."
  exit 0
fi
log "Xcode CLT: $(xcode-select -p)"

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
log "Homebrew: $(command -v brew)"

# ---- 3. brew bundle ----
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  log "Running brew bundle (Brewfile)..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  warn "No Brewfile found; skipping brew bundle."
fi

# ---- 4. oh-my-zsh ----
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installing oh-my-zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
log "oh-my-zsh: $HOME/.oh-my-zsh"

# ---- 5. powerlevel10k ----
P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  log "Cloning powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi
log "powerlevel10k: $P10K_DIR"

# ---- 6. Symlink dotfiles (delegates to install.sh) ----
log "Linking dotfiles via install.sh..."
"$DOTFILES_DIR/install.sh"

# ---- 7. Claude Code CLI (native installer) ----
# Lands at ~/.local/bin/claude with versions under ~/.local/share/claude/versions/.
# Idempotent: re-runs upgrade-in-place if already installed.
if ! command -v claude >/dev/null 2>&1; then
  log "Installing Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
fi
export PATH="$HOME/.local/bin:$PATH"
log "claude: $(command -v claude || echo '(install failed)')"

# ---- 8. uv + MCP tools ----
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv (Astral)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
log "uv: $(command -v uv)"

log "Installing MCP backends via uv (kindex, constrain)..."
# kindex: public PyPI package (author: jmcentire).
# constrain: PRIVATE GitHub repo (jmcentire/constrain) — install needs gh auth
#            wired up first (run `gh auth login` if it errors with 401/403).
#            The PyPI package named "constrain" is a different, unrelated tool.
# --force makes both calls idempotent (reinstalls in-place if already present).
uv tool install --force "kindex[mcp]" \
  || warn "uv tool install kindex[mcp] failed"
uv tool install --force \
  "constrain[mcp] @ git+https://github.com/jmcentire/constrain.git" \
  || warn "constrain install failed (need 'gh auth login'? private repo)"

# ---- 9. Register MCP servers with Claude Code ----
register_mcp_stdio() {
  local name="$1"; local binary="$2"
  if ! command -v "$binary" >/dev/null 2>&1; then
    warn "$binary not in PATH; skipping '$name' MCP registration"
    return
  fi
  claude mcp remove "$name" -s user >/dev/null 2>&1 || true
  claude mcp add    -s user "$name" -- "$binary"
}

if command -v claude >/dev/null 2>&1; then
  log "Registering MCP servers at user scope..."
  register_mcp_stdio kindex kin-mcp
  register_mcp_stdio constrain constrain-mcp
  # serena: no separate install — uvx fetches on first run.
  claude mcp remove serena -s user >/dev/null 2>&1 || true
  claude mcp add    -s user serena -- uvx --from git+https://github.com/oraios/serena \
    serena start-mcp-server --context ide-assistant --open-web-dashboard False
else
  warn "claude CLI not found; install Claude Code, then re-run bootstrap.sh."
fi

# ---- 10. Next steps ----
log "Bootstrap complete."
cat <<'EOF'

Manual steps remaining:
  1. Make zsh the default shell (if not already):
       chsh -s "$(command -v zsh)"
  2. In iTerm2: Preferences > Profiles > Text -> font "MesloLGS NF"
     (otherwise powerlevel10k icons render as boxes)
  3. Restart your shell:
       exec zsh
  4. If ~/.p10k.zsh doesn't exist (first run), p10k will launch the
     configurator automatically. Otherwise run `p10k configure` to tune.
  5. Sign in to GitHub CLI:
       gh auth login
     (Required BEFORE constrain installs cleanly — it pulls from a private
     repo. If bootstrap warned about constrain failing, re-run bootstrap.sh
     after gh auth is set up.)
EOF
