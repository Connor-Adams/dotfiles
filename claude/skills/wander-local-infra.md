---
name: wander-local-infra
description: Working with the Wander backend local development stack — Flox + Colima + k3s + Tilt + Telepresence. Use whenever you touch the wander backend locally (running services, debugging the cluster, invoking colima/tilt/telepresence/kubectl, the wander-* tooling scripts), or when the user asks about local k8s, the Tiltfile, the colima VM, or anything in the tooling-* repos.
---

# Wander Local Infra — AI Operating Notes

**Canonical setup doc:** `tooling-kubernetes/README.md`. Read it before doing setup work. This skill is the AI-specific addendum — failure modes, output hygiene, and conventions that the README does not cover.

## Stack at a glance

```
Flox + direnv (env)
  └─ Colima (macOS Virtualization.framework VM, sparse 100GiB disk)
       └─ containerd + k3s (cluster: k8s context "colima", API on 127.0.0.1:6443)
            └─ Tilt (deploy/watch — per session, not setup)
                 └─ Telepresence (network bridge — per session, sudo + macOS dialogs)
```

- All CLIs (`colima`, `tilt`, `telepresence`, `kubectl`, `wander-colima-*`, `wander-psql`) are **flox-provided**, not on global PATH. They appear when direnv has activated `tooling-kubernetes` (directly or via the `tooling_repos` chain in `wander/.envrc`).
- Outside a direnv-active dir: run via `cd ~/Developer/Work/wander && direnv exec . bash -c '<cmd>'` or `cd ~/Developer/Work/tooling-kubernetes && direnv exec . bash -c '<cmd>'`.
- Tooling repo chain in `wander/.envrc`: `tooling-devshell` → `tooling-deno` → `tooling-kubernetes` → `tooling-postgresql`. Activating wander triggers all four.

## Hard rules

1. **Always pass `--context colima`** to `kubectl` and `tilt`. The `colima` context maps to the local cluster; without it you risk hitting staging/prod. The README states this explicitly.
2. **Filter output of any `wander-*` script that may take secrets in argv.** Several use `set -x` (xtrace) and will echo credentials. Pre-filter:
   ```bash
   <cmd> 2>&1 | grep -vE 'docker-password|--token|--password|secret-data'
   ```
   `wander-colima-setup-infra-repo` is the canonical offender — `set -exo pipefail` echoes a base64 GCP service-account JSON when creating the GAR pull-secret.
3. **Never run a context-less `kubectl` in a script you wrote.** Always `kubectl --context colima ...` even when current-context already is colima — current-context drifts.
4. **Pre-flight before any cluster work:** `kubectl --context colima get --raw=/healthz`. Three seconds, catches VM-zombie cases (see "K3s flapping" below).

## Pre-session checklist (when about to touch the cluster)

```bash
# 1. is the VM up?
direnv exec . bash -c 'colima status'   # should say "running"
# 2. is k3s answering?
direnv exec . bash -c 'kubectl --context colima get --raw=/healthz'   # expect "ok"
# 3. is the GAR pull-secret in place?
direnv exec . bash -c 'kubectl --context colima get secret us-docker.pkg.dev-creds -o name'
```

If any of those fail, see recovery below before running `tilt up`.

## Per-session lifecycle (not setup)

```bash
cd ~/Developer/Work/wander                                        # direnv chain activates
tilt up --context colima -f local-Tiltfile                        # long-running; tilt UI in browser
# in another terminal:
telepresence connect                                              # sudo + may pop macOS dialogs
# … work …
telepresence quit
# Ctrl-C the tilt process (or `tilt down --context colima -f local-Tiltfile` to clean up resources)
```

`local-Tiltfile` and `main-local-Tiltfile` live on `origin/dev`. Feature branches forked before that work landed will not have them — rebase on dev or check out dev temporarily.

## Recovery: known failure modes

### K3s flapping ("connection refused on 127.0.0.1:6443" but `colima status` says running)

Most common cause: corrupt kubelet checkpoint from a prior hard host crash. The VM is long-lived (months); cruft accumulates.

```bash
direnv exec . bash -c 'colima ssh -- sudo systemctl is-active k3s'
direnv exec . bash -c 'colima ssh -- sudo journalctl -u k3s -n 50 --no-pager'
```

Look for: `Failed to initialize allocation checkpoint manager` or `kubelet panic: could not restore state from checkpoint`. The error message typically names the corrupt file. Fix:

```bash
# rename rather than delete (Connor's hook policy blocks rm; mv is reversible)
direnv exec . bash -c 'colima ssh -- sudo mv /var/lib/kubelet/<file> /var/lib/kubelet/<file>.corrupt'
direnv exec . bash -c 'colima ssh -- sudo systemctl restart k3s'
# wait briefly, then:
direnv exec . bash -c 'kubectl --context colima get --raw=/healthz'
```

### "secrets already exists" from `wander-colima-setup-infra-repo`

The GAR pull-secret persists across `colima stop`/`start`. The script isn't idempotent; the existing secret is fine. Verify with:
```bash
kubectl --context colima get secret us-docker.pkg.dev-creds -o jsonpath='{.metadata.creationTimestamp}'
```
If it's months old and pulls still work, leave it. Only delete + re-create if the underlying GCP key has been rotated (would show up as image-pull failures across the team in Slack).

### Disk pressure

Two distinct disks; check both.
```bash
df -h /                                                            # host (APFS sparse — Colima disk grows on demand)
direnv exec . bash -c 'colima ssh -- df -h /'                      # inside VM (ext4)
```
Host pressure: typical offenders are `~/Library/Caches`, old Conductor worktrees, Xcode/simulator data, and Docker (if still installed — `docker system prune -af --volumes`).
VM pressure: `colima ssh -- sudo crictl rmi --prune` for unused images; `kubectl --context colima delete pod ...` for stuck terminating pods.

### Doppler login expired

`wander-colima-setup-infra-repo` and other infra scripts will fail with auth errors. README says: `doppler login` (decline the "download latest Doppler" prompt). Confirm with `doppler me`.

### Hook blocks `rm`

Connor's harness has a policy hook that rejects `rm`. For files that need removing, use `mv X X.corrupt` or `mv X X.bak`. Reversible and passes the hook.

## Tooling repo management

- All tooling-* repos live as siblings under `~/Developer/Work/`. The chain works by `.envrc` `source_env ../tooling-X`.
- Sync command: `wander-tooling sync` (from `tooling-devshell`). Iterates known roles and pulls.
- Known repos: `tooling-devshell` (foundation), `tooling-deno`, `tooling-kubernetes`, `tooling-postgresql`, `tooling-typesense`, `tooling-loadtesting`, `tooling-skills`, plus `flox-project-template`.
- `tooling-skills` is currently empty — Devon's placeholder (created 2026-05-06) for a team-shared skill registry. Don't push to it without checking with Devon first.
- Note: `wander-tooling` script has a stale entry for `tooling-localdev` which doesn't exist on github. Sync still works for the others.

## When working with AI on this stack

- Long-running commands (`tilt up`, `telepresence connect`) — background them; use `Monitor`/`TaskOutput` to follow logs. Don't block the foreground.
- Browser-handoff commands (`doppler login`, `gcloud auth login`) — flag and ask the user, don't try to drive headless.
- VM-internal state requires `colima ssh -- ...`. The AI can't peek at it any other way.
- The Tilt UI (browser) is the fastest way to triage a multi-service deploy issue. Surface its URL to the user; don't try to scrape it.

## What's deliberately NOT in this skill

- The basic happy-path setup walkthrough — that's `tooling-kubernetes/README.md`. Read it.
- The full Tiltfile semantics — read `wander/Tiltfile` and `wander/wander-infra-Tiltfile`. Note `TILTENV`, `TARGET_K8S_CONTEXT`, `TILT_LOCAL_OVERRIDES`.
- Per-service development guides — those live elsewhere in `wander/documentation/`.
