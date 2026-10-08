# Shared Asset Inventory — `/srv/shared/game assets/`

Audited 2026-10-08 by direct directory listing and glTF/GLB JSON parsing (triangle counts
are actual index-buffer counts from sampled models, not estimates).
Updated 2026-10-08: library naming standard adopted (see below); two itch.io packs added
(Modern Interiors, Music Loop Bundle); all directories renamed to the standard.

## Library standard (applies to every pack here)

- **Directory name:** `<Pack>_<Author>` — CamelCase, no spaces, no brackets, no version
  numbers (versions change; the pack identity doesn't). Examples:
  `StylizedNatureMegaKit_Quaternius`, `MusicLoopBundle_Tallbeard`.
- **`SOURCE.txt` in every pack root** (provenance manifest): source URL, fetch date,
  itch rating, tags, license pointer, and the full upstream file list with what was
  fetched vs skipped. Written automatically by the `itch-asset-fetch` skill's
  `itch.py get`; hand-written for manually-added packs.
- **Keep the upstream license file** (`License.txt` / `_LICENSE.txt`) where it is; never
  delete it. If a pack ships no license file, add one to `SOURCE.txt` quoting the page.
- **Extracted archives:** keep the original `.zip` next to the extracted tree only if
  under ~50 MB; otherwise extract and drop the zip (the SOURCE.txt file list preserves
  what the zip contained).
- **Adding a pack:** prefer the `itch-asset-fetch` skill (search → info → vision-check
  the cover → `get --name <Pack>_<Author> --extract`), then add a section to this doc.

**Global facts (verified):**
- **No pack is a Godot project** — zero `project.godot`, zero `.tscn` anywhere. All packs are
  raw DCC exports (FBX / glTF / OBJ). Nothing needs "open in editor once"; everything is
  copy-into-`res://` and let Godot import.
- **No `.blend` files anywhere** — no Blender dependency.
- **Audio: covered as of 2026-10-08** — `MusicLoopBundle_Tallbeard` adds 334 seamless OGG
  music loops (CC0). SFX are still missing (no .ogg/.wav/.mp3 SFX anywhere); Kenney audio
  or freesound CC0 remain the route for those.
- **No rigged animations** — the only skinned mesh found (Universal Base Characters) has
  `animations: 0`. Any game needing character animation must supply its own rig/animations
  (e.g. mixamo-retargeted or Quaternius SOURCE pack, which we don't have).
- Formats present: `.glb` (465), `.gltf+.bin` (139), `.fbx` (824, binary Kaydara format),
  `.obj+.mtl` (121), `.png` (96), `.jpg` (4), `.tga` (1). Godot 4.7 imports glTF and GLB
  natively, binary FBX via the built-in (theufu) importer, OBJ via tinyobjloader, TGA natively.
  **Use the glTF/GLB variants wherever a pack offers them** — fewer import surprises, materials
  come through correctly.
- **License: every pack is CC0 1.0** (verified by reading each license file). Safe for
  GitHub-published, commercial, and redistributed use; attribution optional everywhere.
  See per-pack notes and the redistribution section.

---

## 1. CookingAssets_MilkAndBanana (MilkAndBanana)

- **Contents:** 231 unique cooking props (appliances, pans, knives, boards, bowls, plates,
  cups, utensils, gadgets, chopsticks…) in two parallel trees: `GLB/<Category>/*.glb`
  (+ `GLB/All/` with all 231) and `FBX/<Category>/*.fbx`.
- **Formats:** `.glb` (textures embedded — verified: 1–3 textures per file, no sidecar files)
  and `.fbx`. Use GLB.
- **Style / budget:** stylized low-poly, flat/vertex-ish shading. Measured: dutch oven 372 tris,
  oven 2.5k, rice cooker 7.3k tris. Typical prop ≈ 0.3–3k tris. Files 15–150 KB each.
- **Godot 4.7:** drop `.glb` into `res://assets/…`, imports directly, materials embedded.
- **License:** CC0 (MilkAndBanana, itch.io). Credit optional.
- **Size on disk:** 25 MB.

## 2. PondKit_AssetQuest (Asset Quest)

- **Contents:** 89 FBX meshes — pond basins (Pond_1–4), rocks/pebbles (many moss variants),
  cattails, grass patches, mini plants, branches, plus small creatures (frog, bird, dragonfly
  ×3 variants each), clay pot, tubs.
- **Formats:** FBX only (binary). Textures: `Pond_Plants_Atlas_2K.tga` (plant atlas; **alpha
  channel = plant cutout opacity** — Godot imports TGA fine, but set transparency hint to
  "Alpha" on the plant material) + `Pond_Props_BaseColor.png` (6.5 KB color-swatch atlas).
- **Style / budget:** low-poly stylized nature; readme says metalness 0, one shared atlas.
  No glTF variant → FBX import required (works in 4.7; verify materials re-assign after import
  since FBX material embedding is weaker than glTF).
- **Godot note from readme:** disable backface culling (cull-disabled material) for plants —
  required, not optional.
- **License:** CC0 (Asset Quest). Credit optional.
- **Size:** 8.7 MB (mostly the 9 MB TGA).

## 3. KayKitFurnitureBits_KayLousberg (Kay Lousberg)

- **Contents:** 53 furniture props (beds, chairs, couches, cabinets, lamps, rugs, picture
  frames, pillows, plants, books…) in `Assets/`:
  - `kaykit furniture free/` — **glTF+bin, one shared texture** ← use this
  - `fbx/`, `fbx (unity)/`, `obj/` — duplicates in other formats
  - `texture/furniturebits_texture.png` — single atlas for everything
- **Style / budget:** low-poly stylized, one 1024-ish atlas, no PBR maps. Couch = 636 tris;
  typical prop < 1k tris.
- **Godot 4.7:** copy `Assets/kaykit furniture free/*.gltf+bin` + the texture png (keep the
  relative path the gltf expects, or re-point the material after import).
- **License:** CC0. Credit optional.
- **Size:** 6.7 MB.

## 4. StylizedNatureMegaKit_Quaternius (Quaternius)

- **The boreal workhorse.** 68 models (of 116 in PRO — free tier is partial, stated in license
  file). In `glTF/` (68 × `.gltf+.bin`, textures as sidecar PNGs in the same dir), plus `FBX/`,
  `FBX (Unity)/`, `OBJ/` duplicates and a `Textures/` mirror.
- **Model list (verified):** CommonTree_1–5, Pine_1–5, DeadTree_1–5, TwistedTree_1–5,
  Bush(_Flowers), Clover_1–2, Fern_1, Flower_3/4 (single+group), Grass_Common/Wispy
  (short+tall), Mushroom_Common, Mushroom_Laetiporus, Pebble_Round_1–5, Pebble_Square_1–6,
  Petal_1–5, Plant_1/7 (+big), Rock_Medium_1–3, RockPath_Round/Square pieces (5 each).
- **Textures:** 20 PNGs incl. bark diffuse+normal ×3, leaves/grass/flowers/mushrooms/rocks
  atlases, some `_C` (color-tint) variants. Diffuse+normal only — stylized, not PBR.
- **Budget (measured):** Pine 3.9k, CommonTree 6.3k, Rock 342, Grass 326 tris. Trees 3–7k,
  ground clutter < 500. Good for a survival game at moderate tree counts.
- **Godot 4.7:** copy `glTF/*.gltf + *.bin + *.png` **together, flat** (gltfs reference the
  PNGs by relative filename in the same folder). Alpha-cutout leaves need the transparency
  hint set post-import (glTF import usually gets `KHR_materials` alpha right for these).
- **License:** CC0, free "Standard" tier = 68/116 models; PRO/SOURCE paid (SOURCE has a Godot
  project with the stylized shader — we don't have it; the free glTFs import fine without it).
- **Size:** 111 MB (FBX/OBJ duplicates are most of it; the glTF subset is small).

## 5. UniversalBaseCharacters_Quaternius (Quaternius)

- **Contents:** 2 rigged base characters — **Superhero_Male_FullBody, Superhero_Female_FullBody**
  — in `Base Characters/Godot - UE/` (glTF+bin, **for Godot/UE scale**) and `Unity/` (FBX).
  8 hairstyles in `Hairstyles/Origin at 0/glTF (Godot)/` and 8 in `Rigged to Head Bone/glTF
  (Godot -Unreal)/` (Eyebrows, Beard, Buns, Buzzed, BuzzedFemale, Long, SimpleParted…).
  ~48 PNG textures (basecolor/normal/roughness per character, hair, eyes) — this pack is the
  only PBR-ish one (has roughness maps).
- **Budget (measured):** male FullBody = 14.3k tris, skinned (`skins: 1`), **`animations: 0`**
  — rigged skeleton, no animation clips included.
- **Gotcha (from pack README):** glTF variants exist because Blender→FBX rigged export has a
  scale bug; **use the `Godot - UE` glTFs, not the Unity FBXs**. Use the normals under
  `Textures/Normals Unity - Godot/` (OpenGL +Y convention) if re-wiring materials.
- **License:** CC0, Standard = partial (SOURCE paid adds .blend rigs + Godot project).
- **Size:** 126 MB.

## 6. ModernInteriors_LimeZu (LimeZu)

- **Contents:** free tier of the Modern Interiors RPG tileset — 16×16 top-down interior
  tiles: furniture, floors/walls, characters (idle/run/sit animations as sprite sheets),
  `free_overview.png` preview. `Modern tiles_Free/` tree, PNG spritesheets + tilesets.
- **Formats:** 2D PNG only (not a 3D pack). Godot: import as-is; spritesheets need manual
  region setup or AnimatedSprite2D frames.
- **Style:** cozy Stardew-like pixel interiors, warm muted palette. Vision-checked cover
  suggests effective detail closer to 32×32 than strict 16×16 — verify grid before use.
- **Rating:** 4.9★ (609) on itch. **License: NON-COMMERCIAL ONLY** — `LICENSE.txt` allows
  use/edit in non-commercial projects, forbids commercial use and reselling. Fine for
  jams/prototypes; buy the paid tier before shipping any commercial game with it.
- **Size:** 2.9 MB. `SOURCE.txt` present.

## 7. MusicLoopBundle_Tallbeard (Abstraction Music / Tallbeard Studios)

- **Contents:** 334 seamless music loops, OGG only, flat in pack root, grouped by name
  prefix (Interior Birdecorator, Dani Maccari, Ludum Dare 28, chiptune set, quarterly
  drops 2024–2026). `_LICENSE.txt` + `_README.txt` in root.
- **Formats:** `.ogg` — use OGG, not MP3 (readme: MP3 framing breaks seamless loops;
  Godot's loop points on OGG work correctly).
- **Style:** broad — ambient, chiptune, upbeat, orchestral-ish; covers most genres.
- **Rating:** 4.9★ (325) on itch. **License:** CC0 (public domain) with a non-endorsement
  note: author asks against NFT/ML-training/unmodified-resale use (not license
  restrictions, but respect it).
- **Size:** 1.4 GB extracted (zips dropped per library standard; full file list in
  `SOURCE.txt`). Song-browser/troubadeck player apps were skipped — music only.

---

## Suitability for porting **boreal** (stylized arctic survival)

| boreal need | coverage | source |
|---|---|---|
| Trees (pines, dead, twisted) | ✅ strong | Stylized Nature: Pine_1–5, DeadTree_1–5, TwistedTree, CommonTree |
| Rocks / boulders / pebble scatter | ✅ | Stylized Nature Rock_Medium + Pebbles; Pond kit rocks (mossy — less arctic) |
| Ground clutter (grass, ferns, mushrooms) | ✅ (green — tint or skip under snow) | Stylized Nature grass/fern/mushroom set |
| Character controller mesh | ✅ mesh+rig only | UBC Superhero Male/Female glTF (Godot-UE folder) |
| Campfire | ⚠️ partial | No fire logs/stones pack; KayKit has no campfire. Improvise: Pond `Branch_1–3` as logs + Stylized rocks as fire ring. Flames = own shader/particles |
| Snow terrain | ❌ missing | No snow material/terrain kit in any pack. Procedural: white-blue vertex-tinted terrain + Stylized Nature rocks/trees with a snow-cap shader or vertex-color snow mask |
| Snow-covered trees | ❌ missing | Recolor: trees use `_C` tint atlases (Leaves_GiantPine_C etc.) — shift hue toward desaturated blue-white |
| Aurora sky | ❌ missing | Own procedural sky / skybox shader (Godot `ProceduralSkyMaterial` + custom shader bands) |
| Wolf | ❌ **critical gap** | No quadruped anywhere (Pond kit has frog/bird/dragonfly only). Need external CC0 animal pack (e.g. Quaternius "Animals" pack, Kenney) — must be fetched separately |
| Crashed plane wreck | ❌ **critical gap** | Nothing vehicular. Options: commission a simple low-poly wreck glb, or block it out from KayKit/Cooking primitives (won't look great) |
| Camp/shelter furniture | ✅ | KayKit Furniture Bits (beds, crates→cabinets, lamps, rugs — cabin interior) |
| Cooking/crafting props | ✅ strong | Cooking Assets, 231 props (pots, knives, boards, stove…) — fits survival crafting UI/props perfectly |
| Water (thaw ponds) | ✅ | Pond kit basins + water material |
| Audio (music) | ✅ (as of 2026-10-08) | MusicLoopBundle_Tallbeard — 334 CC0 OGG loops (ambient/chiptune/upbeat) |
| Audio (SFX) | ❌ missing | Still no SFX anywhere; Kenney/freesound CC0 needed |

**Verdict:** Stylized Nature + Cooking + KayKit + UBC give a coherent Quaternius/KayKit-adjacent
stylized look and cover ~60% of boreal's visual needs (flora, rocks, props, character).
**Must source externally before port:** wolf (or substitute another animal), plane wreck,
snow material approach, aurora sky, all audio, and character animation clips.

## License / redistribution (GitHub publication)

- **Packs 1–5 + 7 (Music Loop Bundle): CC0 1.0 Universal** — public-domain dedication,
  verified by reading `License.txt` / `License_Standard.txt` / `_LICENSE.txt` in each.
  Commercial use, modification, redistribution on GitHub: **allowed, no attribution
  required** (all authors ask for optional credit).
- **Pack 6 (ModernInteriors_LimeZu) is NOT CC0 and NOT commercial-safe** — free tier is
  **non-commercial use only** per its `LICENSE.txt`. Do not ship it in a commercial game
  or a public repo that implies commercial intent without checking the paid tier.
- Recommended repo hygiene: keep each pack's original `License.txt` next to the copied subset
  in `game/assets/<pack>/`, and add a one-paragraph credits section to the game README
  (MilkAndBanana, Asset Quest, Kay Lousberg / KayKit, @Quaternius). Costs nothing, avoids
  any bad-faith dispute.
- The two Quaternius "[Standard]" packs are the **free partial tiers** — redistributing them is
  still CC0; just don't imply you have the PRO/SOURCE content.
- No EULAs, no asset-store restrictions, no non-redistributable terms found anywhere.

## Import guidance for porting agents (res://)

1. **Prefer glTF/GLB from every pack.** Never copy FBX/OBJ duplicates into a Godot project —
   they're format duplicates that only bloat the repo (Nature pack: copy only `glTF/`, ~small,
   not the 111 MB).
2. **Cooking Assets:** copy `GLB/All/*.glb` (or per-category subsets) → `res://assets/cooking/`.
   Self-contained, zero sidecars.
3. **KayKit:** copy `Assets/kaykit furniture free/*.gltf|*.bin` **plus**
   `furniturebits_texture.png` (a copy already sits inside that folder; gltfs reference it as
   a sibling — verified `image.uri = "furniturebits_texture.png"`). One flat folder works.
4. **Stylized Nature:** copy `glTF/` contents (gltf + bin + png together, flat) →
   `res://assets/nature/`. Do not split textures into another folder.
5. **Pond Kit:** FBX-only. Copy `Meshes/*.fbx` + `Textures/*` → `res://assets/pond/`; after
   import, re-assign the TGA atlas (alpha = cutout) and set plant materials cull-disabled
   (readme requirement). Or pre-convert to glb once with `godot --headless --import` and commit
   the .glb if FBX materials misbehave.
6. **Universal Base Characters:** copy `Base Characters/Godot - UE/*.gltf|*.bin|*.png` and
   `Hairstyles/…/glTF (Godot)/*` → `res://assets/chars/`. Use these glTFs, **not** the Unity
   FBX (known rigged-FBX scale bug, per pack README). Normals for re-wiring: the
   `Normals Unity - Godot` folders. Expect to add your own animations.
7. **Headless CI:** all of the above import with `godot --headless --import` on first run;
   no editor session is ever required (no project.godot in any pack, no .blend).
