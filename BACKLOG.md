# Backlog

## Terrain generation as a factory capability (separate goal — not in current rounds)
Goal: a reusable, deterministic terrain generator script for generated games — fractal fBm +
hydraulic/thermal erosion, biome painting (treeline, wetland, rock, snow) from elevation/moisture,
output as heightmap + ArrayMesh + collision, seeded from the game's RNG stream.

Notes for whoever picks this up:
- games/boreal/src/sim/terrain.gd + noise.gd already prove the pattern: analytic height function
  shared by sim (gameplay queries) and render (mesh sampling) — keep that property; erosion needs
  a precomputed heightmap, so decide the sim/render contract first (sample the baked map, not live erosion).
- Erosion is iterative and expensive: bake once at authoring time (headless CLI), commit the
  heightmap as data, never re-erode at runtime.
- Determinism: erosion kernels must use the seeded RNG streams; float determinism across machines
  is NOT guaranteed — bake to data, ship the data (same lesson as boreal's IEEE-754 golden tests).
- Biome painting should be pure functions of (height, slope, moisture) so tests can assert biome
  coverage percentages from a seed — semantic test, not screenshot.
- Candidate reference: Unity/Unreal erosion compute shaders are overkill; a simple hydraulic-erosion
  pass (particle or heightfield-based) in GDScript at 256x256 is tractable headless.

## Asset wishlist (user may fetch packs; otherwise procedural/stopgap)
- Plane wreck (boreal crash site) — or procedural stopgap from deformed primitives
- Wolf (boreal predator)
- Audio: ALL current packs have zero audio files (fire crackle, wind, footsteps, ambience)
- Character animation clips (Universal Base Characters rig has 0 clips)
- Stylized water (currently a procedural shader stopgap)
