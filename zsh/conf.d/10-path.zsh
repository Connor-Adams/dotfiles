# PATH helpers
path_add_front() { local p="$1"; [[ -d "$p" ]] && path=("$p" $path) }
path_add_back()  { local p="$1"; [[ -d "$p" ]] && path=($path "$p") }

# User bins
path_add_front "$HOME/bin"
path_add_front "$HOME/.local/bin"

# Homebrew (Apple Silicon default at /opt/homebrew)
if command -v brew >/dev/null 2>&1; then
  local BREW_PREFIX
  BREW_PREFIX="$(brew --prefix 2>/dev/null)" || BREW_PREFIX=""
  [[ -n "$BREW_PREFIX" ]] && path_add_front "$BREW_PREFIX/bin"
  [[ -n "$BREW_PREFIX" ]] && path_add_front "$BREW_PREFIX/sbin"
  [[ -n "$BREW_PREFIX" ]] && path_add_front "$BREW_PREFIX/opt/libpq/bin"
else
  path_add_front "/opt/homebrew/bin"
  path_add_front "/opt/homebrew/sbin"
  path_add_front "/opt/homebrew/opt/libpq/bin"
fi

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
path_add_front "$PNPM_HOME"

# Python user scripts
path_add_front "$HOME/Library/Python/3.12/bin"

# Deno
[[ -r "$HOME/.deno/env" ]] && source "$HOME/.deno/env"

# opencode
path_add_front "$HOME/.opencode/bin"

# Antigravity
path_add_front "$HOME/.antigravity/antigravity/bin"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
path_add_back "$ANDROID_HOME/emulator"
path_add_back "$ANDROID_HOME/platform-tools"

# Java (Zulu 17)
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
