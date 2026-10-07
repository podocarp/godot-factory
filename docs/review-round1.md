# Review round 1 — second opinion on factory v0

Reviewer: independent subagent, 2026-10-08 ~04:30–05:15 +08.
Method: read all docs/scripts/sdk/boreal, ran the harness, broke the scripts,
cloned the repo fresh, ran parallel renders, verified the flake pin with
`nix eval`. Note: **the repo was being actively modified during this review**
(boreal phase-2a: `src/render/`, `assets/`, `vendor/sdk/`, `.github/`,
`test_render.gd` all appeared untracked mid-session; boreal suite went 4/4 →
5/5 while I was probing). Findings below are against the working tree at
05:10; the committed HEAD is `357c40d`.

## 1. Memo promises vs. delivered v0

| Memo promise | Status | Evidence |
| --- | --- | --- |
| Headless authoring (code → PackedScene → .tscn) | ✅ delivered | `sdk/tools/build_prefabs.gd`, `level_builder.gd`, template smoke test; owner-after-add_child pitfall correctly documented in sdk/README |
| Data-first content (JSON spec → scene) | ✅ delivered | `level_builder.gd` + round-trip test; unknown-param reporting is a nice touch |
| Semantic tests, screenshots as escalation only | ✅ delivered | run_tests.sh is fast (sdk 3.6s, boreal 4.8s); render is 9s and documented as slow |
| Visual checkpoints, backend assertion | ✅ delivered | render_shot.sh asserts llvmpipe in the log; docs/rendering.md dead-ends list is the best doc in the repo |
| **Versioned SDK, games pin versions** | ⚠️ hollow | No version string anywhere in `sdk/`. boreal's `vendor/sdk/VENDOR.md` pins by *date copy* ("copied 2026-10-08"). Nothing detects drift between vendored files and `sdk/prefabs/`. |
| **Semantic inspection API** (`world.inspect`, JSON observations) | ❌ missing | No snapshot/observation surface. `boreal/src/sim/world.gd` has no `to_dict`/snapshot; sdk has none. Every game agent will hand-roll assertions against raw fields — exactly the drift the memo warned about. |
| **UI test-id query tool** | ⚠️ half | `test_id` metadata exists on HUD/dialogue nodes, but there is no tool to *query* the UI tree by test_id. The convention is write-only. |
| Headless authoring CLI (command surface) | ⚠️ seeds only | build_prefabs + level_builder are the right shape; no unified `project.validate()`-style entry. Acceptable for v0, but FACTORY.md doesn't tell the next agent what the sanctioned surface *is*. |
| Security sandboxing | ❌ missing | `bubblewrap` is in the flake and used by nothing. `run_tests.sh`/`render_shot.sh` run Godot with full user privileges, full FS, full network. The memo explicitly says generated projects are untrusted; today a generated `main.gd` can `DirAccess` anywhere and `OS.create_process`. |

**sdk/ ↔ games/ integration is untested and mostly fictional.** boreal uses
2 of ~17 SDK files, via a manual copy, and `main.gd` `load()`s them by string
path (no type checking). No game uses `level_builder`, `EventBus`,
`SimDriver`, or `EntityRegistry`. The SDK is currently a parallel artifact,
not a platform. The first game that *composes* the SDK (level JSON + registry
+ event bus + HUD) is the real integration test and doesn't exist yet.

## 2. Harness run results (all real, this session)

- `run_tests.sh sdk` → 5/5, 3.6s. `run_tests.sh games/boreal` → 4/4 (later 5/5), 4.8s. Clean.
- `render_shot.sh games/boreal /tmp/review.png` → OK, 9.4s, valid PNG, backend asserted.
- Flake pin verified: `nix eval --raw github:NixOS/nixpkgs/f9420fcd…#godot.version` → **`4.7.1-stable`**. Host godot is `4.7.1.stable.nixpkgs`. Pin is honest.
- **Parallel renders are safe**: two concurrent `render_shot.sh` on `template` both passed; `$$`-unique socket + per-run `mktemp` XDG_RUNTIME_DIR is a correct design. Zero `/tmp/weston-factory.*` leaks after runs (trap cleanup works on normal exit).

### Break attempts

| Attempt | Result | Verdict |
| --- | --- | --- |
| `run_tests.sh /tmp/nope` | exit 1, clear message | good |
| Failing test (prints FAIL, quit(1)) | exit 1, FAIL surfaced, tail shown | good |
| Test with parse error (no FAIL line) | exit 1, parse errors in tail | good |
| **Test that quits 0 silently, no PASS** | **exit 0, "1/1 test scripts passed"** | **BAD — a test that asserts nothing passes** |
| Test that hangs (no quit) | exit 1 after 120s, but output shows only the engine banner — no "TIMEOUT" marker | confusing failure mode |
| `render_shot.sh --scene res://nope.tscn` | exit 1, "Cannot open file" in log tail | good |
| `render_shot.sh /tmp/nope` | exit 1, but only after paying full weston startup; "backend not asserted" warning is noise before the real error | acceptable |
| **Fresh `git clone` → run_tests.sh boreal** | **0/4 — all tests fail with `Identifier "…" not declared` (class_name cache missing)** | **BAD — see P0-1** |
| Fresh clone + `--import --quit` first | 4/4 pass, render OK | confirms root cause |

## 3. FACTORY.md accuracy

Commands as written: `run_tests.sh`, `render_shot.sh`, `--import --quit`,
`--check-only --script` — all work from repo root and from other cwds with
absolute paths. Issues:

- **Missing the biggest gotcha: a fresh clone (or `cp -r template games/x`)
  needs an import pass before *anything* works** — `class_name` globals are
  resolved from `.godot/global_script_class_cache.cfg`, which is gitignored.
  FACTORY.md mentions import only "after adding assets". This is the first
  wall every new agent hits.
- Status list says CI unchecked while `.github/workflows/ci.yml` exists
  (untracked, in-flight) — will be stale the moment it's committed; and the
  CI as written **runs `run_tests.sh` on a fresh checkout with no import
  pass → first CI run is red** (same failure I reproduced on the fresh clone).
- `.uid` files: correctly committed (Godot 4.4+ needs them stable); template's
  new `.uid` files are untracked — commit them.
- `--quit-after 3600` semantics (frames, backstop) are correctly described.

## 4. Host/environment risks

- **Flake pin: verified good** (see above). `nix develop` shellHook exports
  `VK_DRIVER_FILES`; render_shot.sh also falls back to globbing `/nix/store`
  and (uncommitted) `/usr/share/vulkan` for CI. Fine.
- **Weston collisions: not a risk** — tested, design is correct. Residual:
  `kill -9` of render_shot.sh leaks the mktemp dir and a weston process
  (trap misses SIGKILL). Minor; note it.
- **`/tmp` pollution: OK** in normal operation.
- **Relative `OUT` to render_shot.sh silently writes into the *project* dir**
  (Godot resolves it against `res://`), not the caller's cwd — I got
  `template/rel.png`. Surprising; `realpath` it.
- CI runs on ubuntu-latest with official Godot binary while the host runs
  nixpkgs-patched 4.7.1 — acceptable, but the flake comment "matches the
  engine installed on the factory host" overclaims (`.nixpkgs.a13da4feb` ≠
  `official`).
- No `XDG_RUNTIME_DIR` race: the script always overrides it per-process.

## 5. Security minimum for a service later

Today: zero isolation, and the trust model is already wrong (generated games
run as the agent user with network + full FS). Minimum viable additions,
in order of value:

1. `scripts/sandbox.sh` wrapping Godot in bwrap (already in the flake):
   `--unshare-net --ro-bind engine --bind <proj> --tmpfs $HOME`, plus a
   pre-run scan rejecting `GDExtension`/`gdsdk`/`OS.create_process`-style
   escape hatches in generated projects.
2. Per-project uid/gid or at least per-project HOME so `user://` saves can't
   cross games.
3. Immutable artifact store for logs/PNGs/test results keyed by git SHA
   (memo: reproducibility). None exists.

## 6. Prioritized fix list

**P0 — blocks the next agent / first CI run**
1. **Import pass before tests.** Add `godot --headless --path "$PROJ" --import --quit` to `run_tests.sh` (or a `scripts/bootstrap.sh`), and add it to `ci.yml` before the test loop. Fresh clone currently fails 0/4 with cryptic `Identifier not declared` errors. *(Verified.)*
2. **run_tests.sh must require a PASS line.** Count a script as passed only if it exits 0 **and** printed ≥1 `PASS` and 0 `FAIL`. A silent `quit(0)` currently passes. *(Verified.)*
3. **Commit or stash the in-flight boreal phase-2a work** (13 modified/untracked paths, incl. `template/*.uid` and `ci.yml`). "5/5 tests" in FACTORY.md describes an uncommitted tree — the next agent checking out HEAD gets a different repo than the handbook describes.

**P1 — will bite within the next game**
4. **Semantic observation API.** Add `snapshot() -> Dictionary` to the SDK (registry + inventory + HUD + bus events) and a `tools/inspect.gd` that prints compact JSON; make boreal's `World` expose one too. Without this every agent hand-rolls assertions and the memo's core loop (JSON observation → repair) never starts.
5. **UI test-id query tool.** `tools/ui_dump.gd`: walk the tree, emit `{test_id, role, visible, text, bounds}` per node. The metadata convention exists; the query half doesn't.
6. **Version the SDK.** `sdk/VERSION` (or `const SDK_VERSION`), referenced from `VENDOR.md`; add a CI check that vendored copies byte-match `sdk/prefabs/` — boreal's copy will silently drift otherwise.
7. **Timeout failure mode in run_tests.sh.** On exit 124 print `TIMEOUT <name> after 120s` — currently a hang looks like a mysterious empty failure.
8. **FACTORY.md: document import-pass-after-clone/copy** in Hard rules, and state the sanctioned authoring surface (build_prefabs/level_builder) explicitly.

**P2 — hygiene**
9. `render_shot.sh`: `realpath` the OUT arg (relative paths land in the project dir); validate `$PROJ/project.godot` exists before spawning weston.
10. Note the SIGKILL weston-leak in docs/rendering.md; optionally `trap … HUP INT TERM` + pidfile.
11. `run_tests.sh`: normalize trailing `/` on PROJ before the `res://` prefix strip; document that PROJ should be relative-to-cwd or absolute (both work today, trailing slash does not).
12. Screenshot baseline/perceptual diff (memo §7 tier) — defer to boreal phase 2, but reserve `games/<name>/shots/baseline/` in the layout doc now.
13. bwrap sandbox wrapper + generated-code scan (section 5, items 1–2).

## 7. Genuinely good (one line each)

- `docs/rendering.md` dead-ends table is exactly what an agent handbook needs — negative knowledge with root causes.
- Parallel-safe weston isolation (`$$` socket + mktemp runtime dir) is correct by design and verified under concurrency.
- Boreal golden tests storing floats as IEEE-754 bit patterns to dodge GDScript literal-parsing ULP drift is unusually rigorous; the TS→GDScript bit-exactness bar is the right one.
- Flake pin is honest and verified; failure modes of both scripts are loud with exit codes and log tails.
- The owner-after-add_child / `EventBus.reset()` headless gotchas encoded in sdk/README are the kind of knowledge that normally costs a day per agent.
