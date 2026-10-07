# Godot Game Factory

Agent-facing pipeline for building small playable Godot 4 games headlessly — no editor required.

- **Author**: GDScript builds node trees → `PackedScene` → `.tscn` (validated, diffable output).
- **Test**: semantic headless scenarios (`scripts/run_tests.sh`) + fixed-tick screenshots
  (`scripts/render_shot.sh`, works on GPU-less hosts via weston + lavapipe software Vulkan).
- **Distribute**: GitHub. Engine + toolchain pinned in `flake.nix` (Godot 4.7.1).

Start with [`FACTORY.md`](FACTORY.md) (agent handbook) and `template/` (copy to begin a game).
Constraints of this host and dead-ends already burned: [`docs/rendering.md`](docs/rendering.md).

First demo title: a Godot port of [boreal](https://github.com/podocarp/boreal) (arctic survival),
scope and mapping in `docs/boreal-analysis.md`.
