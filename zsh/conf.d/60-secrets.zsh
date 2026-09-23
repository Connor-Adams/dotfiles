# setkey/listenv — machine-local secrets, loaded into every interactive shell.
#
# Secrets live in ~/.config/secrets/*.env, one line per variable:
#   export NAME="$(echo <base64> | base64 -d)"
# The base64 is obfuscation against casual greps and file indexers, NOT
# encryption — `env` still prints the plaintext. The .env files are gitignored
# (**/*.env) and must never be committed; only these helpers are tracked.
# Never pass a secret as a CLI argument — it lands in zsh_history.
#
# bootstrap.sh sources the same directory from bash; this is the zsh half, so
# interactive shells get the same vars on a machine that has never run bootstrap.

_secrets_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
if [[ -d "$_secrets_dir" ]]; then
  # Distinct loop var: zshrc sources conf.d inside a `for f in ...` loop, so a
  # bare `f` here would clobber the caller's iterator.
  for _secrets_f in "$_secrets_dir"/*.env(N); do
    [[ -r "$_secrets_f" ]] && source "$_secrets_f"
  done
fi
unset _secrets_dir _secrets_f

# setkey NAME — prompt for a value without echoing it, persist to gv.env, export now.
setkey() {
  local name="$1" val
  [[ -z "$name" ]] && { echo "usage: setkey NAME"; return 1; }
  read -s "val?value for $name: "; echo

  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
  local f="$dir/gv.env"
  mkdir -p "$dir"; chmod 700 "$dir"
  touch "$f";      chmod 600 "$f"

  # `-i.bak` plus a cleanup of the backup is the portable form: BSD sed requires
  # an argument to -i, GNU sed does not.
  sed -i.bak "/^export ${name}=/d" "$f" && command rm -f "$f.bak"
  printf 'export %s="$(echo %s | base64 -d)"\n' "$name" "$(printf %s "$val" | base64)" >> "$f"

  export "$name=$val"
  unset val
}

# listenv — names only, never values.
listenv() {
  local f
  local -a names
  for f in "${XDG_CONFIG_HOME:-$HOME/.config}/secrets"/*.env(N); do
    names+=("${(@f)$(sed -n 's/^export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$f")}")
  done
  names=(${(ou)names})
  (( ${#names} )) && print -l -- $names
}
