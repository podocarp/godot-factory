# Sandboxing untrusted generated projects

Generated games are **untrusted code**: a `main.gd` can call `DirAccess`
anywhere the agent user can write and `OS.create_process`. `run_tests.sh` /
`render_shot.sh` run Godot with full user privileges. `scripts/sandbox.sh`
wraps any command in bubblewrap (in `flake.nix`) for untrusted runs.

## Usage

```bash
# bare command
scripts/sandbox.sh -- godot --headless --path /abs/proj --script res://tests/test_x.gd
# project-dir form: the project is COPIED to a temp dir, bound read-write at
# the same path (res:// mapping survives), and the copy is deleted on exit —
# the real tree is never touched.
scripts/sandbox.sh games/foo -- godot --headless --path $PWD/games/foo --import --quit
# knobs: --timeout S (wall clock, default 120) --cpu S (ulimit -t, default 90)
#        --mem-mb N (ulimit -v, default 1536) --net (allow network; off by default)
```

## What bwrap mode gives you (verified on this host, 2026-10-08)

| Property | Mechanism | Verified |
| --- | --- | --- |
| No network | `--unshare-net` | `/proc/net/route` empty inside |
| No `~/.ssh` / `~/.config` leakage | `--tmpfs $HOME` | `ls $HOME` empty inside |
| Host FS read-only | `--ro-bind / /` | `touch /etc/x` → Read-only file system |
| Clean env | `--clearenv` + explicit PATH/HOME/USER | only 7 vars inside |
| PID/IPC isolation | `--unshare-pid --unshare-ipc` | — |
| Wall-clock + CPU + memory caps | `timeout` + `ulimit -t/-v/-f` inside | `sleep 30` under `--timeout 3` → exit 124 |
| Dies with parent | `--die-with-parent` | — |

Real runs (this host, bwrap 0.12.0, user namespaces enabled):

```
$ scripts/sandbox.sh -- godot --headless --version
[sandbox] bwrap mode (net:off, clean env, tmpfs HOME)
4.7.1.stable.nixpkgs.a13da4feb

$ scripts/sandbox.sh template -- godot --headless --path .../template --script res://tests/test_smoke.gd
[sandbox] bwrap mode (net:off, clean env, tmpfs HOME)
PASS smoke: code-authored scene round-trips through PackedScene
```

## Degraded mode (fallback, clearly weaker)

If `bwrap` is missing or the namespace probe fails (e.g. `max_user_namespaces=0`,
hardened kernels refusing unprivileged userns), the script falls back to
`env -i` + `timeout` + `ulimit` **without namespaces** and prints
`[sandbox] DEGRADED mode ... WEAKER`. That gives you: clean env, wall-clock,
CPU time, virtual-memory and file-size caps. It does NOT give you: network
isolation, filesystem isolation, or HOME protection — same user, full host FS
visible. Use it only for semi-trusted code or as a resource governor.

## Honest limits

- **Same uid**: bwrap here runs unprivileged with user namespaces; the
  sandboxed process is still *you* from the kernel's point of view outside
  the namespace. A Godot/engine privilege-escalation bug is still game over.
  Per-project uid/gid (review §5.2) is not implemented.
- **`--ro-bind / /` exposes the whole host FS read-only** (nix store paths
  make selective binds fragile). Secrets readable by the user (dotfiles under
  `$HOME` are tmpfs'd, but e.g. group-readable files elsewhere) are visible.
- **ulimit -v** is a blunt virtual-memory cap; some allocators over-reserve
  and die early. Raise `--mem-mb` if a legit run OOMs at the cap.
- **Not used by run_tests.sh/render_shot.sh yet** — opt-in per invocation.
  Making it the default is a follow-up once CI parity is checked.
- The review's "pre-run scan rejecting GDExtension/OS.create_process" is NOT
  implemented; sandboxing is enforced by the kernel, not by scanning.
