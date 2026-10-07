# FACTORY.md — Godot Game Factory Handbook

Handbook for agents authoring/iterating games in this repo. Read this first; deep dives in `docs/`.
(This file is the project handbook; it is intentionally NOT named AGENTS.md on this host.)

## What this is
A pipeline for LLM agents to build small playable Godot 4 games **without ever opening the editor**:
headless authoring (code → `PackedScene` → `.tscn`), semantic tests (no pixels), and headless
screenshots for visual checkpoints. Host: GPU-less NixOS VM; engine pinned in `flake.nix` (Godot 4.7.1).

## Hard rules
1. **Never hand-edit `.tscn` as the source of truth.** Author scenes in GDScript (`Node` tree →
   `owner` set *after* `add_child` → `PackedScene.pack()` → `ResourceSaver.save()`), or edit them
   only via a generator. Generated `.tscn` is reviewable output, not raw mutable input.
2. **Two Godot modes, never mixed:**
   - `godot --headless --script ...` — sim, serialization, import passes. NO pixels. Fast.
   - `scripts/render_shot.sh <proj> <out.png>` — real pixels via weston+lavapipe. SLOW (CPU).
     Visual checkpoints only. See `docs/rendering.md` for dead ends you must not retry.
3. **Tests are semantic first.** Screenshots are escalation artifacts, not the observation channel.
4. **Assets come from `/srv/shared/game assets/` (quote the path — it has a space) or are
   generated as glTF/PNG.** Check `docs/asset-inventory.md` before creating anything from scratch.
   Mind licenses before publishing on GitHub.
5. **Determinism:** fixed seeds, fixed-step sim (`_physics_process`), no wall-clock in game logic,
   no `randf()` without a seeded `RandomNumberGenerator`.

## Commands
```bash
nix develop                            # pinned toolchain (godot 4.7.1, weston, mesa, gh) — optional; host already has these
bash scripts/run_tests.sh <proj>       # all <proj>/tests/test_*.gd headless, nonzero exit = fail
bash scripts/render_shot.sh <proj> <out.png> [--scene res://x.tscn] [--width N] [--height N]
godot --headless --path <proj> --import --quit          # asset import pass (run after adding assets)
godot --headless --path <proj> --check-only --script res://some.gd   # parse check
```

## Project layout
- `template/` — copy this to start a game. Has a passing smoke test (code-authored scene
  round-trip) and a screenshot harness in `scenes/main.gd` (reads `$SHOT_OUT`).
- `scripts/` — harness (render_shot.sh, run_tests.sh). Keep them boring and robust.
- `docs/` — rendering.md (host constraints), boreal-analysis.md, asset-inventory.md, opencode-setup.md.
- `games/<name>/` — one directory per game; each is a standalone Godot project with `tests/`.

## Test conventions
- `tests/test_*.gd` extends `SceneTree`, prints `PASS <name>` / `FAIL <name>: <reason>`,
  calls `quit(0)`/`quit(1)`. Runs under `--headless` — must not require pixels.
- Acceptance scenarios ("get key → open gate → reach chest") are scripted as test scripts driving
  the sim with fixed seed + `input`/`sim` calls, asserting on world state, not images.
- Visual checkpoints: fixed seed + fixed tick + ≤640x360, saved under `games/<name>/shots/`.

## Distribution
GitHub via `gh` (auth via `GITHUB_TOKEN`/git-credentials on this host). One repo per game or a
monorepo with `games/` — default: monorepo `podocarp/godot-factory`. Never commit secrets;
`.gitignore` covers `.godot/`, `*.tmp`.

## Current status
- [x] Headless render path validated (weston + lavapipe + wayland/vulkan; see docs/rendering.md)
- [x] `flake.nix` pins nixpkgs @ godot 4.7.1; `scripts/` harness verified against `template/`
- [ ] Starter prefab library (camera rigs, FPS/TPS controllers, interaction, inventory, UI kit)
- [ ] Boreal port v1 (see docs/boreal-analysis.md for scope)
- [ ] CI (GitHub Actions: run_tests.sh + render_shot.sh on ubuntu-latest + llvmpipe)
