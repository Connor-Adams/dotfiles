# dotfiles

Personal dotfiles for my macOS dev setup. Managed via symlinks with a manifest-driven `install.sh`.

## What's in here

| Path | Links to | Purpose |
|------|----------|---------|
| `zsh/zshrc` | `~/.zshrc` | Main zsh config |
| `zsh/conf.d/` | `~/.config/zsh/conf.d` | Sourced by zshrc (aliases, etc.) |
| `git/gitconfig` | `~/.gitconfig` | Global git config |
| `git/gitignore_global` | `~/.gitignore_global` | Global gitignore |
| `config/direnv/direnvrc` | `~/.config/direnv/direnvrc` | direnv settings |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code global instructions |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code settings (hooks, permissions, plugins) |
| `claude/hooks/` | `~/.claude/hooks` | Claude Code hook scripts |

The single source of truth is `manifest.txt` — each line maps a tracked file to its target.

## Install

There are two scripts:

- **`bootstrap.sh`** — first-run setup on a fresh machine. Installs Xcode CLT,
  Homebrew, the `Brewfile`, oh-my-zsh, powerlevel10k, then delegates to
  `install.sh`. Idempotent; safe to re-run.
- **`install.sh`** — just creates symlinks per `manifest.txt`. Run this on
  its own whenever the manifest changes.

### Fresh machine

```bash
git clone https://github.com/Connor-Adams/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

Follow the manual steps printed at the end (`chsh`, iTerm2 font, `gh auth login`).

### Already-bootstrapped machine

```bash
cd ~/.dotfiles
./install.sh
```

The installer backs up anything it's about to overwrite to
`~/.dotfiles-backup/<timestamp>/`, then creates symlinks per the manifest.
Re-running is safe — it skips files already linked correctly.

## Adding a new file

1. Add the file to the repo under a logical directory.
2. Add a line to `manifest.txt`: `<source-path> <target-path>`.
3. Run `./install.sh`.
4. Commit.

## Keeping in sync

These files live as symlinks, so edits in place (e.g., `~/.zshrc`) automatically flow back to the repo. Commit and push to share across machines.

If a config drifts because it was edited directly at the target path (not through the symlink — can happen with tools that rewrite files), copy it back manually and commit.
