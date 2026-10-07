# BOREAL → Godot 4.7.1 Port Analysis

Source: `/persist/hermes/workspace/boreal-src` (TypeScript + three.js + Vite, MVP complete @ tag `v0.1-mvp`, sprint 8 balance in progress).
This doc is the single reference for the porting agents. All file paths below are relative to `boreal-src/` unless noted.

---

## 1. Gameplay spec (engine-agnostic)

### Scenario loop
Bush plane crashes on a subarctic lake shore (~60°N, late autumn, Survivorman-style). One run = 6–10 in-game days; the player must survive and be **seen** during a search window on days 7–10, or die with an explanatory summary. Core loop per day:

1. **Morning**: needs have moved overnight (energy restored only if you slept warm/fed; core temp dropped if you slept exposed). Assess fire (may have died), weather, needs.
2. **Gather window** (~8 h of light, 09:00–17:00 game time): chop deadfall, snap boughs, peel bark, scoop snow/water, check snares, fish, pick berries, scavenge the wreck (once).
3. **Camp maintenance**: feed fire, melt/boil water, cook meat, craft (tinder bundles, cordage, bark containers), build shelter steps.
4. **Night** (17:00–09:00): wolves spawn from day 2; fire + shouting repel them. Sleeping is the nightly gamble: warm+sheltered+fed = full restore; exposed = hypothermia risk.
5. **Days 7–10**: two search-plane passes per day (dawn ~09:00, dusk ~16:30). Detection = signal smoke (big lever) > flare (one shot, ~0.95) > campfire/position/tracks. Storms can scrub a pass. Day 10 without rescue → forced "gave up" death.

Primary sources: `src/sim/world.ts` (state + step + all actions), `docs/VISION.md`, `docs/DESIGN-world.md`, `docs/PLAN.md`.

### Player needs (`src/sim/needs.ts`, `src/sim/config.ts` CONFIG.NEEDS/THERMO)
Four needs + one physical model, all 0–100 except core temp:

| Need | Decay/game-h (Ranger) | Debuffs from | Death at 0 |
|---|---|---|---|
| Hydration | 1.75/h (≈2.4 d) | <45: focus | ~8–10 h |
| Hunger | 1.0/h (≈4 d), ×1.5 shivering | <45: strength, heat production | ~20 h |
| Energy | 4/h awake (×1.3 moving, ×2.2 sprinting) | <45: dexterity, focus | no direct death; forces risky sleep |
| Health | only drains in critical bands (<15) | — | 0 |
| Core temp | heat-budget model, 37 °C nominal | cold<36 shiver, <34.5 dexterity, <33 hypothermia (confusion + 8 HP/h, ×3 below 30 °C) | hypothermia |

Key mechanics:
- **Windchill** = Environment Canada formula (`windchill()` in needs.ts); no windchill above 0 °C.
- **Heat budget** °C/h: `gain (fire 2.6 + exertion 1.2 + metabolic 0.6·food-fuel) − loss (0.07·|feels-like| / insulation)`; wetness guts insulation (soaked = 40%). Clamped ±2.5/1.5 °C/h. Tuning targets are unit-tested: walking at feels −25 °C ≈ neutral; idle at −20 → hypothermia in ~5 game-h.
- **Food = fuel for heat**: hunger <25 reduces metabolic heat; shivering raises hunger drain.
- **Auto-sip**: idle + hydration <60 + carrying treated water → auto-drink (no chore).
- **Craving curve** (S8): food restores `base × (1 + 0.8·(1−hunger/100))` — grazing is strictly worse.
- **Debuffs** (`computeDebuffs`): steadiness/dexterity/strength/focus multipliers feed fire-lighting rolls, work speed.
- Difficulty multipliers on decay: bushman 0.7 / ranger 1 / survivorman 1.3.

### Actions (`src/sim/world.ts` action functions, `src/sim/actions.ts` contextual layer)
Contextual scheme (S8b): one primary verb (LMB/E on nearest target) + hold-RMB radial wheel listing only what's possible *here, now*, priority-ordered: gather target > spot verbs (collect snare, fish) > fire verbs (feed/cook/boil/signal/treat) > light fire > eat/drink/sleep/shelter/snare > craft > flare. Disabled options show a reason hint. All verbs are pure sim functions; `actions.ts` is unit-tested without a browser.

Gathering = timed work tasks (0.1–0.5 game-h, `WORK_HOURS` in `interact.ts`), slowed by dexterity debuff, cancelled by moving. Crafting = 6 atomic recipes (`craft.ts`: kindling, tinder bundle, bark container, bough bundle, cordage, torch). Inventory: 22 items, stack limits + 18 kg carry limit (`items.ts`).

### World systems
- **Terrain** (`src/sim/terrain.ts`): hand-authored *analytic* functions — `heightAt(x,z)` (fbm base + western ridge + bog flattening + stream carve + lake basin at y=0) and `zoneAt` → lake/stream/bog/ridge/forest. Shared by sim (collision, speed mul, wind exposure) and render (mesh) so they can never disagree. World = 400 m half-size square. Crash site `CRASH = (-20,-62)` on the lake south shore; guaranteed spruce grove 15–45 m away (`scatter.ts`).
- **Scatter** (`src/sim/scatter.ts`): 1400 deterministic props (spruce/birch/rock) from value noise, zone-weighted, plus the starter grove; colliders derived from the same list.
- **Fire** (`src/sim/fire.ts`): fuel 0–100 → 5 stages; burn rate %/h `[0,30,18,10,7]` (stage 4 ≈ 14 h = survives the 15-h night), wind speeds burning; warmth radius `[0,3,4.5,6,7.5]` m. Friction-light roll: base 0.6 ± dexterity/wetness/core-temp/wood-dry, clamped 0.05–0.9; relaying from an existing fire never fails.
- **Shelter** (`src/sim/shelter.ts`): 6-step debris shelter (site/frame/ribs/insulation/mulch/bedding) with material costs; site quality scored from wind/water/fuel/widowmaker/dryness noise fields; insulation = progress × (0.45+0.55·quality), feeds thermoregulation within 2.5 m.
- **Storms**: scripted schedule — day 2 light (20:00, 6 h, sev 0.45), day 4 heavy (18:00, 9 h, sev 0.85). Effects: wind ×(1+1.6·sev), wetness gain 0.12·sev/h (¼ if sheltered), snare catch halved, scrub rescue passes >0.5.
- **Wolves** (`src/sim/dangers.ts`): 2–3 spawn per night from day 2 (seeded `w.seed + day*97`), gone at dawn. FSM: prowling (keep 25–40 m, strafe) → circling (acquiring) → attacking → retreating/fleeing. Fairness rules: 0.8 s reaction delay, fire-radius deterrence, shout (Space) raises fear → flee at >1.4, only interested when player weakened (cold/hurt/low needs) or >fire-radius away at night; bite 8–14 raw dmg + injury, 4 s cooldown. They "finish the already-dying", not horror.
- **Snares/fishing/injury** (`dangers.ts`): snare catch p/h = 0.06·(0.3+quality)·freshness·snowMul, snare destroyed on catch; fish holes with dawn/dusk bonus (0.65 vs 0.4); injury → 5%/h infection → sepsis 6 HP/h (applied *after* 2 HP/h regen so untreated infection is lethal); duct-tape first aid is finite.
- **Rescue** (`src/sim/rescue.ts`): fixed schedule days 7–10 × dawn/dusk; `detectionChance`: base 0.02, signal smoke +0.9 open / +0.5 canopy, campfire +0.3/+0.1, flare ≥0.95, ridge +0.1, visible shelter +0.08, recent tracks +0.05, cap 0.98.

### Win/lose
- **Win**: a search pass rolls under detection → `w.rescued` (day, kind dawn/dusk).
- **Lose**: health ≤ 0 with named cause (hypothermia/dehydration/starvation/infection/wolf attack/exposure — death chains must be *nameable*), or day > 10 → collapse end.
- End screen: title + cause + last 10 log highlights + restart (`src/ui/hud.ts` `showEndScreen`).

### Time model
- Fixed sim timestep `SIM_DT = 0.25` **real seconds**; accumulator loop.
- **dt is real seconds everywhere**; 1 game-hour = 30 real s (`REAL_SECONDS_PER_GAME_HOUR`); convert before any per-game-hour math. 1 day = 12 real min; 6–10 days ≈ 72–120 min.
- Day rolls at hourOfDay ≥ 24; day counter 1-based; run starts day 1 @ 08:00.

### Save model
None shipped (post-MVP backlog). Cheap by design: sim state is pure serializable data (`WorldState` is plain JSON-able, RNG stream is a counter `rngN`).

---

## 2. Sim-vs-presentation boundary

**The one rule** (`docs/TECH.md`, `docs/AGENT.md`): `src/sim/*` is pure — no renderer, no DOM, no wall clock, no `Math.random`. Everything in section 1 above is sim. Presentation reads state, never mutates needs/economy:

| Layer | Files | Role |
|---|---|---|
| Sim | `src/sim/*` | state, step, all actions, RNG, terrain math |
| Render | `src/render/scene.ts`, `camera.ts`, `daynight.ts`, `palette.ts` | meshes, third-person camera math (pure, testable), sky/light from hourOfDay, palette |
| UI | `src/ui/hud.ts`, `menu.ts` | DOM HUD (clock/bars/warnings/prompt/inventory/log), radial action wheel |
| Input | `src/input/input.ts` | keyboard/mouse → `MoveIntent` + key/mouse consumption |
| Wiring | `src/main.ts` | rAF accumulator, mesh sync from sim state, `window.__boreal` debug/E2E API |

**Must stay deterministic in the port:**
- All rolls via `roll(w)` on the serializable `rngN` counter stream (`world.ts:138`): `makeRng((seed*0x9e3779b9) ^ (rngN*0x85ebca6b))()` — mulberry32 (`rng.ts`). Never seed from `w.t` (frozen-time bug, `docs/AGENT.md`).
- Terrain/noise: `hash2`/`valueNoise2`/`fbm2` (`noise.ts`) — integer hash, exact float ops.
- Scatter placement, hare sign, fish holes, wolf spawn ring, interactable generation — all seeded from `world.seed`.
- Fixed timestep: same tick count + same action sequence ⇒ identical world. The E2E golden path and the Monte-Carlo harness (`tests/sim/balance.ts`) both depend on this.

**Key constants worth keeping verbatim** (`src/sim/config.ts` + inline): `SIM_DT=0.25`, `REAL_SECONDS_PER_GAME_HOUR=30`, `RESCUE_WINDOW_DAY=7`, `COLLAPSE_DAY=10`, `SIZE_M=400`, `TEMP_BASE_C=-12`, `TEMP_SWING_C=6`, all NEEDS/THERMO rates (they are unit-test-asserted tuning targets), fire burn `[0,30,18,10,7]`, warmth radii, `CRASH=(-20,-62)`, storm schedule, search schedule, detection table, `WOLF_SPEED_MPS=2.6`, camera constants (`CAM` in `render/camera.ts` — pure math, port as-is).

---

## 3. Port mapping (boreal concept → Godot node/system)

| Boreal | Godot 4.7.1 |
|---|---|
| `WorldState` + `step()` | Plain `RefCounted` class `WorldSim` (gdscript) holding a Dictionary/typed state; **no Node needed** — keep it headless-testable. |
| rAF accumulator loop | `Node._physics_process` with fixed step: Godot's physics tick is 1/60 s by default; run an accumulator calling `sim.step(0.25)` so sim rate stays 0.25 s real regardless of frame rate. Do **not** tie sim rates to `Engine.physics_ticks_per_second`. |
| `updatePlayer` (analytic collision vs prop circles) | Keep as pure sim math (circle push-out), *or* CharacterBody3D + `move_and_slide` — but then collision behavior diverges from the tested sim. Recommend: keep analytic sim collision; player node is a visual follower. |
| `heightAt`/`zoneAt` analytic terrain | GDScript port of `terrain.ts` + `noise.ts` (single source of truth, same as boreal). Render mesh built by sampling it into an `ArrayMesh`/`HeightMapShape3D` once at load. |
| three.js terrain mesh (128×128 plane, vertex colors, flat shading) | `ArrayMesh` from the same grid + `StandardMaterial3D` with `flat_shading=true`, `vertex_color_use_as_albedo`; or `GridMap`-free simple approach. 128×128 is fine for lavapipe. |
| Instanced trees/rocks (`InstancedMesh`) | `MultiMeshInstance3D` (one per prop kind) with transforms from the ported `scatter()`. |
| three.js scene graph sync (`syncFireMeshes` etc.) | A `PresentationSync` node each frame: read `WorldSim`, add/remove/reposition fire/shelter/wolf visual scenes. Fires: mesh + `OmniLight3D` scaled by stage; flame shader/particles optional upgrade. |
| three.js camera (`camera.ts` pure orbit math) | `Camera3D` under a `Node3D` rig; port `updateCam()` math directly (shoulder pivot, pitch clamp, collision ease). Camera collision raycast: `PhysicsDirectSpaceState3D.intersect_ray` or keep analytic prop-circle ray test. |
| Day/night (`daynight.ts`) | `DirectionalLight3D` + `WorldEnvironment` (ambient + `Fog`); drive sun angle/intensity/color and fog from `hourOfDay` with the same smoothstep curves; keep sun-due-south behavior. |
| DOM HUD (`hud.ts`) | `CanvasLayer` + `Control` nodes: `Label` clock/temp, `ProgressBar`×4, warning labels, prompt line, inventory box, event log. Refresh at ~4 Hz like the original. |
| Radial action wheel (`menu.ts` + `actions.ts`) | Port `actions.ts` unchanged (pure). Wheel = custom `Control` with `_draw()` (arc slots + labels), hold-RMB opens, mouse steer, release executes; pointer-lock via `Input.mouse_mode`. |
| `window.__boreal` debug/E2E API | Autoload singleton `GameAPI` (or `Engine.get_debug_hook`): `reset(seed)`, `step(n)`, `move(f,s)`, `setPaused`, action wrappers — the headless test scripts call these directly. |
| Playwright pixel smoke | `render_shot.sh` (weston+lavapipe, `godot-factory/scripts/`) + `get_viewport().get_texture().get_image()` → PNG, then Python pixel-signature checks (same orange-spruce/cool-ground heuristics). |
| Vitest unit tests | `godot --headless --script` SceneTree tests via `godot-factory/scripts/run_tests.sh` (pattern already in `template/tests/test_smoke.gd`). |

---

## 4. KEEP / IMPROVE / CUT — recommended v1 scope

### KEEP (the game is the sim; port it whole)
- The full needs/thermoregulation model with its tuning targets — it's balanced, unit-tested, and the Monte-Carlo harness exists.
- Contextual action layer (`actions.ts`) — one verb + one wheel; it's pure and already validated by playtest.
- Fire stages + friction roll + nursing-the-fire tension; 6-step shelter with site scoring; sleep gamble; wolves with fairness rules; injury→sepsis chain; rescue detection table; storms; craving curve; death-cause narrative + end summary.
- Analytic terrain shared sim↔render; deterministic scatter; `CRASH` layout (grove/stream/fish-hole proximity was a hard-won playtest fix).
- Deterministic `rngN` stream and fixed timestep (the entire test strategy rests on it).

### IMPROVE (Godot gives these cheaply)
- **Graphics**: real lighting — `DirectionalLight3D` shadows (subarctic low sun = long shadows, huge sell), soft shadows off on lavapipe if slow; snow `FogVolume`/height fog; flame `GPUParticles3D` + smoke column for signal fire (signal smoke is *gameplay*, make it visible); aurora/gradient sky via `Sky`+`ProceduralSkyMaterial`; better tree silhouettes (2–3 LOD-free low-poly variants, keep flat shading + `palette.ts` colors).
- **Feel**: camera bob/FOV on sprint, screen-edge vignette + desaturation as core temp drops (confusion debuff made visible), heartbeat audio cue, fire crackle, wind loop scaled by `windKmh`, wolf growl proximity fade. Audio is boreal's biggest gap (none exists).
- **UI**: proper themed HUD (bars with icons, day/clock dial, minimap-free zone compass), action wheel with icons + greyed reasons (boreal has text only), toast-style event log instead of one-line tail, death screen as a designed panel with the event-chain timeline.
- **Assets**: replace box-wolves with a simple low-poly wolf mesh (Kenney/quaternius-style CC0), crash-plane prop, footprint decals (`Decal` node — tracks-in-snow is a *detection input*, make it readable).
- **Player**: keep "no animations" as fallback but a 2-clip walk/run (mixamo rig or simple leg-swing shader) is a big cheap win.

### CUT for v1 demo (recommended: **15-minute run, days 1–3 compressed**)
Concrete v1 scope:
- **Time scale**: raise `REAL_SECONDS_PER_GAME_HOUR` 30 → 60–75 s *per day pacing* — better: keep 30 s/h but end the run at day 3: move `RESCUE_WINDOW_DAY` to 3, `COLLAPSE_DAY` to 4, storm schedule to days 1–2. One full day-night ≈ 12 min; a tight run = loot → fire night 1 → shelter + food day 2 → signal + rescue pass day 3. (All one-constant changes in `config.ts` equivalents — the sim doesn't care.)
- **Cut**: wolves (keep the code path, disable spawn — removes the harshest death and the bot-regression problem), snares/fishing (keep fishing only if time — it's 20 lines; cut snares), crafting to 3 recipes (tinder bundle, cordage, bark container), difficulty presets (ranger only), trapper's cache/widowmaker/tea (never built anyway), torch/boughBundle items.
- **Keep cut-able but stub**: injuries (wolf bites gone → only fall/chop injuries later), auto-sip (keep, it's free).
- **v1 acceptance**: golden path (loot wreck → tinder → fire → boil → shelter → sleep → signal smoke → day-3 rescue) runs headless to `rescued` in <60 s wall time, plus 3 screenshots (day camp, night fire, rescue pass) that pass pixel checks.

Full 6–10 day experience stays the v2 target once the ported sim passes the golden-path test at original constants (proves parity first, *then* rescale).

---

## 5. Test strategy port

Boreal's pyramid: 87 vitest unit tests on pure sim (`tests/unit/*.test.ts`) + Playwright E2E driving `window.__boreal` (`tests/e2e/smoke_render.py`, 12 numbered checks) + Monte-Carlo balance harness (`tests/sim/balance.ts`).

**Unit → `godot --headless --script` (gdscript, SceneTree pattern already in `godot-factory/template/tests/test_smoke.gd`, runner `scripts/run_tests.sh`):**
Because the ported sim is a plain RefCounted with no engine deps, port the vitest files near-1:1:
- `test_needs.gd` ← `tests/unit/needs.test.ts`: **keep the tuning-target tests verbatim** (walking at feels −25 ≈ stable; idle at −20 → hypothermia in 4–6 game-h; fire beats worst windchill; soaked = 40% insulation; death-at-0 timings). These are the port's correctness oracle for float behavior.
- `test_terrain.gd` ← `terrain.test.ts`: golden values — hard-code ~20 `(x,z)→height` and zone samples computed from the TS implementation and assert GDScript matches within 1e-6. Same for `valueNoise2/fbm2` and mulberry32 `makeRng(seed)` first-100 outputs.
- `test_fire.gd`, `test_shelter.gd`, `test_dangers.gd`, `test_rescue.gd`, `test_actions.gd`, `test_items.gd`, `test_craft.gd`, `test_interact.gd`, `test_player.gd`, `test_world.gd` ← their vitest twins.
- `test_golden_path.gd` ← E2E check #10: pure-sim scripted run (loot → light → signal → fast-forward → assert `rescued.day == 3` in v1 / 7 at parity), plus determinism test: run twice with seed 1, assert identical `world.t`-keyed state hash.
- GUT is optional; the `--script` + `quit(exit_code)` convention matches the factory runner and needs no addon.

**E2E → two tiers:**
1. **Semantic headless** (`run_tests.sh`): boot the real scene with `--headless` (dummy renderer), drive through the `GameAPI` autoload exactly like `smoke_render.py` drives `__boreal` — sim clock, scripted movement, contextActions at wreck, fire loop, shelter+sleep loop, golden path, end-state. No pixels.
2. **Render smoke** (`render_shot.sh`, weston+lavapipe): a `shot_mode` scene that reads env `SHOT_OUT` + a `SHOT_POSE` env (day|camp|night), sets `hourOfDay`, teleports player/camera to the deterministic poses (port poses A/B from `smoke_render.py:259-278`, re-aimed for the Godot camera), awaits `RenderingServer.frame_post_draw`, saves PNG. Then a Python checker replicates the pixel signatures: cool-ground fraction in bottom quarter, orange (wreck `0xd4622a`) pixel count, dark-green spruce count, distinct-color count, plus new ones: fire-lit orange glow at night pose, signal-smoke column presence.

**Screenshot checkpoints (minimum set):**
- `day_camp`: noon, on the bank at (-20,-58) looking at the wreck — asserts terrain, wreck, grove.
- `grove`: grove edge (-40,-6) looking into canopy — asserts spruce silhouettes vs sky.
- `night_fire`: hour 22, lit fire stage 4 — asserts point-light glow pixels against dark sky (proves day/night + fire visuals).
- `signal`: signal fire + smoke column at noon — asserts smoke visible (gameplay-critical visual).
- `hud`: any pose — assert HUD region has non-background pixels (UI actually drawn).

**Balance harness**: port `tests/sim/balance.ts` bots as a `--script` tool (`balance.gd`) once sim parity is proven; it's the tuning loop for the v1 15-min rescale.

---

## 6. Risks / gotchas

1. **dt units — the #1 historical bug class in this codebase.** `dt` is *real seconds*; every rate is per *game hour* and must be divided by 30 (`dtGameH`). GDScript port must keep the conversion in exactly the same places (`world.ts:133`, `needs.ts:168`). Godot's `_process(delta)` is also real seconds — good — but never let a per-frame `delta` reach a needs formula without the accumulator + conversion.
2. **Float determinism TS↔GDScript.** Both are IEEE-754 doubles for `float`, and mulberry32/value-noise use only exact ops (`Math.imul` → GDScript needs care: GDScript `int` is 64-bit; emulate 32-bit multiply with masking, e.g. `(a * b) & 0xFFFFFFFF` after coercing to signed 32-bit — `Math.imul` semantics are easy to get wrong). `>>>` unsigned shifts don't exist in GDScript — implement with `int(x) & 0xFFFFFFFF` handling. **Do not** use Godot's `RandomNumberGenerator`/`FastNoiseLite` anywhere in the sim. Golden-value tests (5.terrain) are the guard; expect ±1 ULP drift at worst, but hash2's integer path must be bit-exact or scatter diverges.
3. **RNG stream discipline.** All sim rolls go through `roll(w)` on `rngN`; never `randf()`, never seed from `w.t` (real bug: frozen time ⇒ identical rolls, `docs/AGENT.md`). Wolf spawn uses its own `makeRng(seed ^ 0x5eed)` — port that too.
4. **Ordering inside `step()` is load-bearing**: sepsis damage *after* regen (untreated infection must out-drain regen); sleep energy restore in `world.step`, not `tickNeeds` (double-apply bug fixed once); storm wetness before fire drying; wolves before needs. Port `step()` line-order, don't "clean it up".
5. **Terrain mesh vs sim height agreement**: build the render mesh by sampling the *same* GDScript `heightAt` (no FastNoiseLite, no `HeightMapShape3D` separate data source). If you add a physics heightmap for camera rays, derive it from `heightAt` too.
6. **Fixed timestep vs Godot's physics**: if you use any `RigidBody3D`/`CharacterBody3D`, its 60 Hz physics will desync from the 0.25 s sim ticks. Keep movement analytic (as boreal does) or step the sim from `_physics_process` with an accumulator and treat visuals as pure followers.
7. **Camera convention mismatch**: boreal uses y-up, yaw 0 = −z, pitch>0 = look down, `atan2`-style facing. Godot is y-up/right-handed with different forward conventions (`-Z` forward, `rotation.y` sign). Port `camera.ts` math literally into a rig rather than using `SpringArm3D` shortcuts, and re-derive the E2E pose yaws (the π offsets in `smoke_render.py` are three.js-specific).
8. **Headless rendering on the GPU-less host**: only the weston+lavapipe path works (`godot-factory/docs/rendering.md`; Xvfb/EGL-X11 are dead ends). Software Vulkan is slow — keep v1 materials cheap (no SSR/SDFGI/GI probes; `gl_compatibility` or `mobile` renderer may be fine and much faster under lavapipe; test both). Long timeouts for shots; assert the llvmpipe backend line as `render_shot.sh` does.
9. **GDScript `Dictionary` iteration order** is insertion-ordered — inventory/log code that iterates (`invLine`, `feedFire` while-loops) is order-sensitive in output text but not in sim state; keep it deterministic anyway for golden tests.
10. **`Math.imul`/`|0` semantics in noise hash** (see 2): a wrong sign here silently changes every scatter position → the starter grove can vanish → "nearest treeline is a mile away" regression returns.
11. **Balance drift after rescale**: moving rescue to day 3 invalidates the storm schedule (day 2/4) and wolf cadence (day 2+); re-run the ported balance harness after any time-scale change — boreal's S8 log shows fed-fire-dies-mid-night and sleeping-player-as-easy-meat were exactly this class of bug.
12. **Work-task timing**: `WORK_HOURS` are converted to real seconds at task start (`startTask`) and ticked with dexterity scaling; shelter steps use a 0.4-game-h task. If you change `REAL_SECONDS_PER_GAME_HOUR` for the 15-min demo, gather tasks scale automatically — verify they don't become sub-tick (<0.25 s) or absurd.

---

*Analyzed 2026-10-08 from boreal-src @ main (sprint-8 WIP). Sim LOC ≈ 2 100 (src/sim), presentation ≈ 900, tests ≈ 1 000 — the sim port is the project; everything else is Godot-native glue.*
