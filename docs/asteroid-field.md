# Asteroid field: research and test map

An experiment for the second level: a band of asteroids round the star, with gaps the bus flies through freely. Flying through the rocks instead slows the bus and bumps the passengers. This page records how the field is drawn and why, what the test map measured, and what is still open. Nothing here is in the game yet.

## Try it

Open `test/previews/asteroid_field_preview.tscn` and run it with F6. It is the real solar system with the field added between Giant and Frost, and Frost moved out from 17.5 to 21 to make room. Three commuters going to Frost are on board, so the bumps show in their happiness bars, and "Rough ride!" shows over the bus as it flies into the rocks.

- Tune it live: in the Remote tree, select `AsteroidField` and change the Ride numbers, or `belt` for the band and its gaps. Rock count and shapes apply only at load.
- `-- Rocks` flies the bus from Ember straight into the rocks, with the camera on it. `-- Gap` flies it along the nearest gap. These are for `capture`, or for the editor's Main Run Args.

## How it is drawn

**MultiMesh, with rock meshes built in code.** Not particles, and no Blender model yet.

- **Two `MultiMeshInstance3D`s:** 900 rocks (an 80-face icosphere, 0.12 to 0.42 across) and 2,400 pebbles (20 faces, 0.03 to 0.09). That is two draw calls and about 120k triangles for the whole belt, with one shader. A MultiMesh is drawn as one instanced draw call per mesh, which WebGL 2 does natively.
- **Nothing updates per frame on the CPU** but the belt's turn: the field rotates its own node, so every rock moves with one transform. Each rock tumbles on its own axis in the vertex shader, from per-instance custom data, and holds still under Reduce motion.
- **The rocks are generated at load** (`RockMesh`): an icosphere pushed in and out by noise, with a flat normal per face. Under the shared two-tone light (`shared/two_tone_light.gdshaderinc`, lit from the star), each facet is either lit or night-tinted, so they read as cut stones in the flat, cartoony look with no textures. Per-rock size, squash and shade come from the instance transform and colour.
- **The shader is `unshaded`** and lights itself in `fragment()`, as the planets do. A custom `light()` costs about 1.5 s to compile on the web. It is one new material, about 200 ms on first draw in Chrome on Windows, and it sits in `material_override`, so `SceneFlow`'s warm-up compiles it under the loading card.

**Why not particles.** `GPUParticles3D` works in Compatibility, but it fits things that are born and die, not a fixed belt. A static belt would need a custom process shader holding every particle in place, re-simulated every frame (an extra GPU pass), for no gain over a MultiMesh. The gameplay can't read particle positions back either, so the gaps would have to be defined separately anyway. Particles do fit effects on top: a puff of dust on each bump would be a good use. Sub-emitters and `emit_particle()` don't work on the web (`docs/web-constraints.md`), so use a one-shot emitter.

**Why not one node per rock.** 3,300 `MeshInstance3D`s would mean 3,300 draw calls and 3,300 nodes for the scene tree to process: the expensive part on the single-threaded web build.

**Blender is still an option** if the generated shapes look too samey. Export a few rocks as one `.glb` (the `blender-models` skill) and give each MultiMesh one of its meshes. Nothing else changes. Generating them in code fits "everything is generated from shaders and meshes" (`docs/ui.md`) and costs no asset.

**Not measured:** frame rate in a browser. Headless capture says nothing about a laptop iGPU. Check it in the preview build with Show FPS, and drop `pebble_count` first if it is slow.

## How it plays

- **The geometry is maths, not physics** (`AsteroidBelt`): a band from `inner_radius` to `outer_radius`, cut by straight gaps of `gap_width` at `gap_angles`. A gap has parallel sides, so it is as wide at its outer end as at its inner one. The bus is among the rocks when its centre is in the band and outside every gap, with `clearance` (0.2) of slack, so brushing a gap's edge doesn't count.
- **Among the rocks, flying:** the bus brakes to `rough_speed` (0.4, a third of its 1.2 top speed) at 3 units/s², and every 0.8 s a rock knocks it. Each knock is a shock of −1.5 to everyone on board, plus a small camera shake toward the bus's heading. Holding still among the rocks, or being towed, costs nothing.
- **Measured on the test map** (a 2.2-wide band, crossed straight): through the rocks, 3.8 s among them and 6 bumps, about −9 happiness, against 1.8 s and nothing through a gap. That's about 2 s lost, plus the shocks.

## What the test map turned up

1. **Moving gaps are hard to hit.** With the belt turning once in 300 s, a gap halfway across moved 0.36 units/s. The bus crossing straight in 1.8 s drifted 0.65 units sideways and clipped the rocks, even aimed at the gap's centre. At 600 s and 1.8 units wide (the defaults now), a straight run through the middle stays clear. Open question: should the belt turn at all? Fixed gaps are landmarks the player learns. Turning gaps fit the pitch ("a route that looks short at the dock may not be short by the time the bus gets there"), but the player has to lead them, and a route set at the dock can't know where the gap will be.
2. **The penalty mostly wears off.** Shocks climb back at 1 a second (`DESIGN.md`, Happiness), so −9 is gone about 9 s later. On a long ride the rocks cost mainly the 2 s, through timing. If the rocks should cost a star, lower the target while among them, as the heat's discomfort does, or make each bump bigger.
3. **The route can't show it yet.** The route line, the trip arc, the fuel forecast and `estimate_time_to_next_planet` all assume a straight run at full speed. A player needs to see before leaving that a leg crosses the rocks. Shading that part of the route line would do it.
4. **Two systems now write the bus's speed cap.** `HeatZone` sets `FrameshiftBus.speed_cap` every frame. The field runs after it (`process_priority = 1`) and takes the lower of the two. That holds only while `HeatZone` exists and runs first. For the real level, the solar system should combine both into one cap, or the bus should take one per source. `bus.gd` is at 579 of 600 lines, so that belongs in a component.
5. **The first system has no room for it.** Giant's rings reach 15.4 and Frost's dock 16.7, so a belt fits there only by moving Frost. A band about 2 units wide needs its own space in the second level's layout, with no planet's dock inside it.
6. **Rocks pass through the bus.** Nothing moves them aside. A cheap fix is a `bus_position` uniform the vertex shader pushes nearby rocks away from, so the bus seems to part the field with no CPU work per rock.
7. **Left out of the experiment:** the zoomed tutorial map (the field doesn't hide on it), the balance tool's scripted player (it flies straight through), saving, and sound.
