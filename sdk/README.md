# godot-factory SDK

Starter systems + code-authored prefabs for games built by this factory.
Everything here runs headless: `bash scripts/run_tests.sh sdk` from the repo root.

## Using the SDK in a game

**Copy it in (recommended):** `cp -r sdk/core sdk/items sdk/prefabs sdk/level_builder.gd games/<name>/`
and merge the `[input]` actions from `sdk/project.godot` into the game's
project.godot (`move_forward/back/left/right`, `sprint`, `interact`). Games stay
standalone Godot projects (FACTORY.md layout), and the SDK files are yours to
modify per game.

**Reference it:** add the sdk dir as a second res:// search path or symlink
`sdk/` into the game project. Works, but the game is no longer standalone —
prefer copying.

Regenerate prefabs after editing any builder script:

```bash
godot --headless --path sdk --script res://tools/build_prefabs.gd
godot --headless --path sdk --import --quit
bash scripts/run_tests.sh sdk
```

## Core (`core/`)

| Class | What |
| --- | --- |
| `EntityRegistry` (Node) | id -> Node lookup; `register(node, id)` renames the node to the id (stable addressing); entries are weak refs, freed entities vanish. |
| `EventBus` (RefCounted) | Typed global signals via `EventBus.bus()`: `item_picked_up`, `interacted`, `trigger_fired`, `quest_updated`, `inventory_changed`. No string signal names. Call `EventBus.reset()` at the end of `--script` tests. |
| `SimDriver` (Node) | Fixed-step clock: `ticked(tick, dt)` at `tick_rate` (60 Hz), seeded `rng`, `simulate(seconds)` for tests, `reset(seed)` for replays. Add to group `sim_driver`. |
| `Inspect` | Semantic snapshots (memo §5): `Inspect.snapshot(tree.root, opts)` → `{tick, nodes:[{path,type,id,state}], events:[...]}`; node state from a `snapshot()` method if present, else curated props. `opts`: `group`/`type`/`id_prefix` selectors, `max_nodes` cap (+`truncated` flag). `record_events()` logs EventBus signals into snapshots. |
| `SnapshotDiff` | `diff(a, b)` → `{added, removed, changed:[{path,key,old,new}], new_events}` — compact deltas for the observe→repair loop; `is_empty(d)` gate. |
| `UiQuery` | UI automation tree (memo §6): `query(root[, test_id])` → `{test_id, role, visible, enabled, text, rect}`; `click_by_test_id(root, id)` emits `pressed` without mouse coords (refuses hidden/disabled/missing). |
| `SdkVersion` | `VERSION` const ("0.1.0"), mirrors `sdk/VERSION`; `scripts/check_vendor.sh <game>` byte-checks vendored copies against sdk/. |

## Prefabs (`prefabs/*.tscn`)

All `.tscn` files are **generated** by `tools/build_prefabs.gd` (+
`tools/prefab_defs_actors.gd`, `tools/prefab_defs_world.gd`). Never hand-edit
them — edit the builders and rerun.

| Prefab | Root / script | Params (exported) |
| --- | --- | --- |
| `camera_first_person.tscn` | `Camera3D` / `FirstPersonLook` | `sensitivity` (0.0025), `pitch_limit_deg` (89). `apply_look(dx,dy)` for tests. |
| `camera_third_person.tscn` | `SpringArm3D` / `ThirdPersonCamera` | `target_path`, `sensitivity`, `pitch_limit_deg` (70), `distance` (4), `spring_length_speed`. Collision avoidance via the spring-arm ray. `move_basis()` for camera-relative movement. |
| `player_first_person.tscn` | `CharacterBody3D` / `PlayerMover` | `walk_speed` (4), `sprint_speed` (7), `gravity`, `camera_pivot_path`. Children: capsule Collision+Mesh, `CameraFirstPerson`, `Inventory`. Test hook: `test_input` (Vector2 right/forward). |
| `player_third_person.tscn` | `CharacterBody3D` / `PlayerMover` | same, plus `CameraThirdPerson` rig following via `target_path`. |
| `interaction_system.tscn` | `Node` / `InteractionSystem` | `player`, `eye` (defaults to viewport camera), `range` (3), `action` (`interact`). Raycasts from the eye, highlights `Interactable` (`highlight_changed`), `try_interact()` emits `interacted(target)`. |
| `inventory.tscn` | `Node` / `Inventory` | `capacity` (10), `item_db`. `add_item/add_item_id/remove_item/count_of/has_item`, `to_dict()/from_dict()`, `changed` signal + `EventBus.inventory_changed`. In group `inventory`. |
| `ui_hud.tscn` | `Control` / `HudController` | `max_health`, `toast_duration`. Unique nodes `%HealthBar %QuestList %ToastLabel %Crosshair` (each with `test_id` metadata). `set_health()`, `add_quest/update_quest`, `notify()` (toast queue advanced by SimDriver). |
| `pickup.tscn` | `StaticBody3D` / `Pickup` (extends `Interactable`) | `item` (Item), `count`, `inventory_path` (`Inventory` under player; falls back to group `inventory`). One-shot; disables itself. |
| `trigger_zone.tscn` | `Area3D` / `TriggerZone` | `event_name`, `once` (true). Emits `fired(name)` + `EventBus.trigger_fired`; `reset()` rearms. |
| `dialogue_box.tscn` | `Control` / `DialogueBox` | `show_line(speaker, text)`, `show_choices(..., options)`, `pick(i)` -> `choice_selected(index)`. Unique nodes `%SpeakerLabel %TextLabel %ChoiceList`. |

Base contracts: `Interactable` (`can_interact()/interact()/on_interact()`,
`cooldown` enforced against the SimDriver clock) and `Item` (`id`,
`display_name`, `icon`, `stackable`, `max_stack`).

## Level spec (`level_builder.gd`)

`LevelBuilder.new().build_from_file("res://levels/spec.json", "res://levels/level_01.tscn")`
builds a level scene from JSON:

```json
{
  "name": "level_01",
  "entities": [
    {
      "prefab": "res://prefabs/pickup.tscn",
      "id": "gem_1",
      "transform": { "pos": [1.5, 0.5, -2.0], "rot_y": 1.5708, "scale": [2, 2, 2] },
      "params": { "prompt": "Take gem", "cooldown": 0.5 }
    }
  ]
}
```

- `id` becomes the node name (EntityRegistry convention: address by id).
- `transform` is optional; `pos`/`scale` are `[x, y, z]`, `rot_y` radians.
- `params` are applied with `node.set(key, value)`; unknown keys are reported
  in `BuildResult.errors` (build still succeeds — games may extend prefabs).
- Any prefab works, including nested ones (players contain cameras/inventory).
- `build(spec_dict)` returns a `BuildResult` (`ok`, `errors`, `root` — free it
  after `save()`).

## Adding a new prefab

1. Add the behavior script under `prefabs/` (keep it <150 lines, tabs, WHY-comments).
2. Add a builder method to `tools/prefab_defs_actors.gd` or `prefab_defs_world.gd`
   and a `_build(...)` line in `tools/build_prefabs.gd`.
   Gotchas: set `owner` **after** `add_child`; every descendant must be owned by
   the **packed root** (`_build` re-owns for you) — children owned by a
   container are silently stripped by `PackedScene.pack()`.
3. Add a round-trip case to `tests/test_prefabs.gd` (and behavior to
   `tests/test_systems.gd` if it has logic).
4. `godot --headless --path sdk --script res://tools/build_prefabs.gd && bash scripts/run_tests.sh sdk`.

## Test conventions

`tests/test_*.gd` extend `SceneTree`, print `PASS`/`FAIL` lines, `quit(0/1)`.
Two headless gotchas encoded in the existing tests:

- During `_init` no node is "in tree" (`get_tree()` is null, `_ready` hasn't
  run) and freeing tree children there corrupts the heap at exit — run suites
  from `process_frame.connect(_run, CONNECT_ONE_SHOT)`.
- Anything connected to `EventBus.bus()` must be dropped with `EventBus.reset()`
  before `quit()`, or the static singleton keeps freed locals alive.
