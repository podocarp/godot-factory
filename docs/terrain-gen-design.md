# Terrain Generation as a Factory Capability — Design Doc

Deliverable for the BACKLOG "terrain-gen" goal. Target implementer: a GDScript agent building
`tools/terrain_bake.gd` (authoring-time CLI) + `src/sim/terrain.gd` (runtime sampler) in a game
project. Everything here is constrained by the factory hard rules: bake erosion to data at
authoring time, biomes as pure functions, determinism via seeded RNG, semantic tests first.

Benchmarks below were measured **on this host** (GPU-less NixOS VM, Godot 4.7.1.stable,
`godot --headless --script`, GDScript interpreted, no native extensions).

---

## 1. Factorio findings — the spawn/starter-patch model

Factorio's evolution is the best public case study of "guaranteed playable start without
hand-placing anything." Key facts, with sources:

**Two separate starting areas.** (a) An *enemy* starting area: an almost-circular radius around
spawn with no enemy bases / demolisher territory; its size slider only pushes enemies out and has
no other effect. (b) A second, *internal, constant-size* starting area that directly controls
resources, cliffs, and water near spawn.
— [Factorio Wiki: Map generator](https://wiki.factorio.com/Map_generator)

**Hard guarantees inside the internal starting area** (0.17+):
- ≥1 patch each of coal, iron, copper, stone — "in very predictable amounts", usually one patch
  per resource, patches "usually close together", non-overlapping, never covered by water.
- Always a lake, *even when water generation is off*.
- Never any cliffs.
- Uranium and crude oil are **excluded** from the starting area (must be sought further out).
— [Wiki: Map generator](https://wiki.factorio.com/Map_generator),
[FFF #258 "New autoplace"](https://factorio.com/blog/post/fff-258)

**The richness gradient.** Outside the starting area, "resource patch richness increases by
distance from the starting area" — the 'not too rich at spawn, richer further out' gradient is a
deliberate multiplier ramp on distance, not noise luck.
— [Wiki: Map generator → Resources](https://wiki.factorio.com/Map_generator)

**Design rationale (Twinsen, FFF #258):** players were regenerating maps until "fat patches +
oil + uranium at spawn"; the fix was *predictability at spawn, randomness beyond it*: "blaming
poor game experience on RNG is just bad design." Starting-area ores use a **separate spot-noise
expression** from world ores. — [FFF #258](https://factorio.com/blog/post/fff-258)

**Algorithm shape — spot noise (the generator primitive):** per region: (1) generate random
candidate points; (2) compute density/quantity/radius/**favorability** from noise expressions;
(3) compute a target total quantity for the region; (4) **sort candidates by favorability**;
(5) take from the top until the target quantity is reached. Suitability can encode elevation so
spots skip water — "the system would then continue through the list of candidate spots, placing
more spots at locations above water to compensate."
— [FFF #258](https://factorio.com/blog/post/fff-258)

**Algorithm shape — iterative regeneration until constraints pass:** pre-0.17 the official
plan was "pre-generating rather large part of the world around start and checking if it meets
the requirements" ([forums, Random Map Generator](https://forums.factorio.com/viewtopic.php?f=18&t=8016)),
and the quick-start guide literally tells players to hit Restart until the four resources + water
are proximate ([Wiki: Quick start guide](https://wiki.factorio.com/Tutorial:Quick_start_guide)).
0.17 moved the guarantee *into* the generator (spot noise + special starting-area elevation
function — [forums, cliffs thread, TOGoS](https://forums.factorio.com/viewtopic.php?f=182&t=54664):
"Elevation in the starting area is generated using a different function… to guarantee certain
characteristics"). Enemy expansion likewise uses per-chunk **distance-weighted scoring**
(`10/(10 + player_structures_weighted + …)`) — scoring, not hard exclusion.
— [Wiki: Enemies](https://wiki.factorio.com/Enemies)

**Scale reference:** starting-area size is an *area* multiplier; 600% ≈ 1.2k tiles no-resource/
no-biter radius, i.e. default ≈ ~110–150 tiles (1 tile = 1×1 entity cell ≈ our ~2 m).
— [forums t=88144](https://forums.factorio.com/viewtopic.php?t=88144),
[steam discussion](https://steamcommunity.com/app/427520/discussions/0/3194745319525365991/)

**Extracted algorithm shape (what we copy):**
1. Generate the world *first* (or a large enough neighborhood of it).
2. Inside a fixed starter radius, *force* guarantees: minimum resource patches (one per kind,
   close together, on land, non-overlapping), one water body, no impassable features.
3. Outside the radius, let randomness run, with a richness/danger **gradient by distance**.
4. Candidate placement = generate → score (favorability) → sort → take-until-quota, with
   fallback to next-best candidate when a constraint (e.g. "not underwater") fails.
5. Fallback at the whole-map level remains "regenerate with next seed" — cheap for us.

---

## 2. Terrain generation for a small game — what's tractable

### 2.1 Base heightmap: fBm
Standard recipe (matches boreal's `NoiseSim.fbm2`): sum octaves with `lacunarity λ = 2.0`,
`persistence/gain p = 0.5`, 4–6 octaves; real terrain ≈ 1/f noise so these defaults read as
natural ([mysimulator fBm article](https://mysimulator.uk/articles/procedural-terrain-generation),
[moonjump terrain overview](https://moonjump.com/game-dev-mechanics-procedural-terrain-generation-how-it-works)).
Optional: ridged fBm (`1-|n|`, squared) for mountain ridges; a second independent low-frequency
noise field for **moisture** (Minecraft-style two-axis biome grid).

### 2.2 Erosion: droplet hydraulic + talus thermal
Droplet hydraulic erosion (Beyer / World Machine style; pseudocode in
[mysimulator erosion tutorial](https://mysimulator.uk/content/tutorials/terrain-generation-erosion.html),
[tessapower writeup](https://tessapower.xyz/blog/simulating-hydraulic-erosion),
[Benes & Beneš heightfield erosion](https://cs.purdue.edu/homes/bbenes/papers/Benes02WSCG.pdf)):
per droplet, per step — bilinear gradient ∇h; `dir = dir·inertia − ∇h·(1−inertia)`; move by
`dir·stepSize`; `Δh = h(new)−h(old)`; capacity `= max(−Δh, minSlope)·speed·water·sedimentCapacity`;
deposit excess / erode deficit; `speed = √(speed² + Δh·gravity)`; `water *= (1−evaporation)`.
Droplets mutate the heightmap **in place** so later droplets see carved channels (this is what
emergently grows river networks).
Thermal erosion (talus/angle-of-repose): for each cell, if `h − h_neighbor > talus_threshold`,
move `transfer·(diff − threshold)` from high to lowest neighbor; a few dozen full-grid passes.

### 2.3 Biomes: Whittaker-style rules on (elevation, moisture, slope)
Whittaker's biome diagram maps temperature×precipitation to biomes
([Whittaker overview](https://sk.sagepub.com/ency/edvol/multimedia-atlas-of-global-warming-and-climatology/chpt/whittaker-biome-model));
game implementations substitute elevation for temperature and add slope
([EcoSim world-system doc](https://github.com/GTFerguson/EcoSim/blob/main/docs/technical/systems/world-system.md),
[terrain-webgpu biome plan](https://github.com/maxfelker/terrain-webgpu/blob/main/BIOME_PLAN.md)).
Our rule set (pure function, testable, §4): `biome = f(h_norm, moisture, slope)` with hard bands —
water below `water_level`; wetland where `moisture > m1` near water level; forest on gentle
mid-slopes with `moisture > m2`; grassland mid/low + dry; rock where `slope > s1`; snow above
`h > h_snow` (treeline). Backlog requirement satisfied: coverage % per seed is a semantic test.

### 2.4 Measured GDScript throughput (this host, Godot 4.7.1 headless, interpreted)
Micro-benchmark (`PackedFloat32Array` heightfield, boreal-style integer-hash value noise):

| Workload | Measured | Extrapolation |
|---|---|---|
| pure mul-add loop | **20.5 Mops/s** | — |
| loop with `sin()` | 6.6 Mops/s | libm calls cost ~3× |
| `valueNoise2` sample (4×hash2+lerps) | **85 k samples/s** | — |
| fBm 256×256, 5 octaves | — | **≈ 3.8 s** |
| fBm 512×512, 5 octaves | — | ≈ 15 s |
| droplet erosion 200 k droplets × 40 steps | **6.1 s** | 1 M droplets ≈ 30 s |

**Verdict:** 256×256 (2 m cells over 512 m) is comfortably tractable for a full authoring-time
bake: fBm 4 s + 500 k droplets 15 s + 30 thermal passes ≈ **< 45 s total**. 512×512 doubles
everything and buys sub-meter detail we won't render on lavapipe anyway — **default 256×256**,
allow 512 as a config knob. Never run any of this at runtime (§5).

---

## 3. Starter-patch scorer — recommended algorithm

Generic, game-agnostic; runs inside the bake CLI after the heightmap/biome/resource fields exist.
Mirrors Factorio: hard guarantees + soft ranking + gradient + regenerate fallback.

### Pipeline (numbered)
1. **Bake fields** (seeded): `height` (fBm + optional ridged), erode (hydraulic droplets, then
   thermal passes), `water_level` percentile, `moisture` (independent fBm), `biome` per cell,
   `resource` spots per kind via spot-noise (candidates → favorability = f(noise, land,
   non-overlap) → sort → take-until-quota), `prop` scatter (trees/rocks from biome density).
2. **Candidate spawn points**: jittered grid over land cells (`h > water_level + 0.5`),
   stride 8 cells (16 m) → ~256 candidates at 256².
3. **Hard constraints (must-pass, else candidate discarded)** — the Factorio guarantees:
   - Flat: height variance over r=8 m disc ≤ `flat_var_max` AND max slope ≤ `flat_slope_max`.
   - Water: nearest water cell (pool or stream) ≤ `water_max_dist` (60 m).
   - Resources: each starter kind (iron/copper/coal/stone ↔ trees/berry/stone/clay per game)
     has ≥1 spot with center ≤ `res_max_dist` (120 m).
   - Buildable: ≥ `build_area_min` (400 m²) of flat-land cells within 25 m.
   - Not in a biome that is impassable (deep water, cliff/rock if cliffs exist).
4. **Soft score (rank the survivors)** — weighted sum, each term normalized 0..1:
   `score = w_flat·S_flat + w_water·S_water + w_res·S_res + w_view·S_view + w_escape·S_escape + w_animal·S_animal`
   - `S_flat`: 1 − var/var_max (flatter is better, but hard gate already passed).
   - `S_water`: 1 − d_water/water_max_dist, **penalized** (×0.3) if d < 8 m (flood/plain-spawn-in-lake).
   - `S_res`: **band score, Factorio's "moderate not maximal"**: for each kind, count spots in
     ring [30, 120] m → full credit; spots inside 30 m → 0.5 credit (too rich at spawn);
     richness multiplier ramps with distance from spawn (gradient, §1).
   - `S_view`: fraction of 16 compass rays (r=80 m) hitting scenic biome (water/ridge/forest).
   - `S_escape`: ≥ `escape_routes_min` (2) passable corridors at 60 m in distinct 90° sectors
     (not spawn-trapped by water/cliff).
   - `S_animal`: animal spawn points within [40, 100] m → credit; within 15 m → 0 (not on spawn).
5. **Pick**: sort by `(score desc, hash(x,z) asc)` — the hash is the **deterministic tie-break**
   (no float-equality luck, stable across runs and machines because it's integer).
6. **Fallback ladder**: (a) relax soft weights only, never hard gates; (b) if zero candidates
   pass hard gates → **relocate**: expand candidate stride to 4 cells and re-run; (c) if still
   zero → bump seed (`seed = hash(seed, attempt)`) and re-bake, up to `max_regens` (8);
   (d) final fallback: place at highest-scoring soft candidate and emit a `WARN` diagnostic
   listing which hard gates failed — tests then fail loudly with a reason, never silently.
7. **Emit** `spawn.json` + baked data (§4 contracts). Runtime game code only *reads* the data.

### Parameter table (defaults)

| Param | Default | Meaning |
|---|---|---|
| `grid_size` | 256 | heightmap cells per side (2 m cells → 512 m world) |
| `fbm_octaves` / `persistence` / `lacunarity` | 5 / 0.5 / 2.0 | base fBm (§2.1) |
| `height_amplitude` | 60 m | fBm → meters |
| `droplets` × `max_steps` | 500 000 × 64 | hydraulic bake ≈ 20 s |
| `inertia / sedimentCapacity / erosion / deposition / evaporation` | 0.05 / 4 / 0.3 / 0.1 / 0.02 | Beyer-style defaults (§2.2) |
| `thermal_passes / talus / transfer` | 30 / 1.0 m / 0.5 | angle-of-repose smoothing |
| `water_level` | 28th percentile | guarantees ~28% water incl. spawn lake via step 3 |
| `spawn_radius_flat` | 8 m | flatness disc radius |
| `flat_var_max / flat_slope_max` | 0.35 m² / 8° | hard flat gates |
| `water_max_dist` | 60 m | hard water gate |
| `res_max_dist / res_ideal_band` | 120 m / [30, 120] m | hard gate / soft band |
| `build_area_min` | 400 m² @ ≤25 m | hard buildable gate |
| `escape_routes_min` | 2 @ 60 m | soft |
| `animal_band` | [40, 100] m, min 15 m | soft |
| `soft_weights` | flat .20 water .20 res .30 view .10 escape .10 animal .10 | sums to 1.0 |
| `candidate_stride / max_regens` | 8 cells / 8 | §3 steps 2, 6 |

---

## 4. JSON output contracts

`baked/terrain.json` (committed data — the runtime source of truth):
```json
{ "version": 1, "seed": 12345, "grid": 256, "cell_m": 2.0,
  "height_m": "terrain_height.f32",  "biome_id": "terrain_biome.u8",
  "biomes": ["water","wetland","grassland","forest","rock","snow"],
  "water_level_m": 4.2,
  "resources": [ {"kind":"iron","x":103.0,"z":-44.0,"amount":900,"radius_m":9.0} ],
  "props":     [ {"kind":"spruce","x":12.0,"z":30.0,"scale":1.1} ],
  "animals":   [ {"kind":"hare","x":-60.0,"z":12.0} ] }
```
(`height_m`/`biome_id` point at raw binary arrays — `PackedFloat32Array`/`PackedByteArray`
`store_buffer` output; JSON holds metadata only.)

`baked/spawn.json` (the *why*, for semantic inspection per factory philosophy):
```json
{ "spawn": { "x": 12.5, "z": -30.0, "y": 5.1, "yaw": 1.57 },
  "seed": 12345, "attempt": 0,
  "hard":  { "flat_var": 0.21, "max_slope_deg": 5.3, "water_dist_m": 34.0,
             "res_dist_m": {"iron": 55, "copper": 88, "coal": 41, "stone": 96},
             "buildable_m2": 610, "passable": true, "passed": true },
  "scores":{ "flat": 0.82, "water": 0.61, "res": 0.74, "view": 0.55,
             "escape": 1.0, "animal": 0.40, "total": 0.71 },
  "rank": { "candidates": 241, "passed_hard": 57, "rank": 1 },
  "diagnostics": ["res coal inside 30 m band: credit halved", "WARN none"] }
```
Tests read these fields directly — an agent can assert *why* a spawn won, not just that one exists.

---

## 5. GDScript implementation notes

- **Bake to data, ship the data.** Float determinism across machines/versions is NOT guaranteed
  (same lesson as boreal's IEEE-754 golden tests, BACKLOG.md). The bake CLI runs once on this
  host; games load `.f32`/`.u8` arrays + JSON. Runtime code may only bilinear-sample the baked
  map — never re-run noise/erosion/scatter at runtime.
- **Sim/render contract**: extend the boreal pattern — `heightAt(x,z)`/`biomeAt(x,z)` become
  bilinear samplers over the baked arrays (pure, shared by sim and mesh build). Keep
  `NoiseSim`-style integer hash (`_i32`/`_imul` masking, noise.gd) for all *bake-time* RNG;
  never `randf()`/`RandomNumberGenerator`/`FastNoiseLite` inside anything golden-tested.
- **`PackedFloat32Array` vs `float`**: heightfield storage is f32 (file size), but GDScript
  `float` is f64 — do erosion math in f64 locals, store f32; document that the *baked file* is
  the determinism boundary, so f32 rounding is frozen at bake time and is fine.
- **Erosion in-place mutation order** is part of the output: iterate droplets in seeded-RNG
  order, single-threaded. No `Array.sort()` on floats without the integer tie-break key.
- **Bake CLI shape**: `godot --headless --path <proj> --script res://tools/terrain_bake.gd --
  --seed 12345 --out res://baked/` — SceneTree script, prints one `BAKE OK <path>` line,
  `quit(0/1)` (mirrors the test contract so CI can gate on it).
- **Cost guard**: assert bake wall-time < 120 s in the bake script itself; if a param change
  blows it, fail loudly rather than hanging CI.

## 6. Validation strategy

Semantic tests (`tests/test_terrain*.gd`, `run_tests.sh`, no pixels):
1. `test_spawn_hard.gd` — read `spawn.json`: flat_var ≤ 0.35, slope ≤ 8°, water_dist ≤ 60,
   every starter resource ≤ 120 m, buildable ≥ 400 m². Fail prints the offending field.
2. `test_spawn_band.gd` — resource counts in [30,120] band ≥ 1 per kind; no resource spot
   center < 15 m from spawn; ≥1 animal point in [40,100] m and none < 15 m.
3. `test_determinism.gd` — re-run the *bake* twice at seed S in-process; assert byte-identical
   height/biome buffers and identical `spawn.json` (this also guards GDScript float drift on
   this host); plus golden: seed 12345 → spawn (x,z) within 1e-6 of committed value.
4. `test_biome_purity.gd` — biome coverage % from seed within band (e.g. forest 25–55%,
   water 20–35%); biome is a pure function: `biomeAt` re-derived from baked h/moisture/slope
   matches baked `biome_id` everywhere.
5. `test_erosion_sane.gd` — post-erosion min/max height sane; ≥1 connected water body ≥ 1%
   area; no NaN.
Screenshot checkpoint (escalation artifact only): `render_shot.sh` at spawn pose, yaw from
`spawn.json`, ≤640×360 — pixel check: ground pixels present, water fraction > 0 in frame
(camera aimed at nearest water), no all-black frame.

## 7. Open questions for the implementer
- Resource kinds are game-specific (boreal: spruce/berry/clay/stone; factory-game: iron/copper/
  coal/stone) — keep the scorer generic over a `starter_kinds: Array[String]` config.
- Whether `spawn.json` lives per-seed in git (yes for the golden seed; other seeds regenerate
  on demand) — default: commit seed 12345's bake, gitignore the rest.
