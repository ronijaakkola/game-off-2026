# Hazy edges

Scene: `hazy_edges.tscn` (inherits `styles/style_base.tscn`). Reference: soft, flat, low-contrast shading with no outlines, where silhouettes and shadow borders are ragged and hazy, almost hand-painted (tree edges, a bush silhouette, the shadow edge on a road).

## Technique

Two parts: flat patches to have borders worth smearing, and one full-screen pass that does the smearing.

- **Flat surfaces** (`hazy_surface.gdshader`): one tint where the sun reaches, one where it doesn't, a narrow edge between them, no gradient or specular. The building keeps its colormap, pulled 35% toward grey (`mute`) and multiplied by a blue-grey `shadow_tint` in shade. Same sRGB-add trick as flat shadows (ambient white at 1, `light()` adds `lit - shadow`), so the sun colour and energy need no tuning.
- **The haze** (`hazy_edges.gdshader`): a 2x2 quad under the camera, the same set-up as cross stitch and sharp-lines' `edge_pass`. Each pixel reads the finished scene from a nearby spot instead of its own. Flat areas read the same colour wherever they read from, so only borders change.
  - **The offset comes from noise fixed in the world.** The pass rebuilds the pixel's world position from the depth buffer and samples 3D value noise there (a slow wobble, 0.25 m cells, plus small teeth, 0.1 m cells, at 25% weight). The offset is made in view space and projected back, so it is `amount` metres on the surface (0.03 m, about 6 px here) and the haze is the same size on a near and a far object.
  - **Three reads, each with its own noise.** They share the wobble and differ by `haze` (0.35), so a border becomes a short band of partly covered pixels instead of a clean line. With `haze` 0 the border is ragged but sharp.
  - No outline, no ink: the raggedness is the paint edge itself, which is what keeps it apart from Moebius's hand-drawn strokes.
- Light energies: base sun 0.35 / ambient 0.5 are overridden: ambient is white at 1 and the sun's energy is ignored.

## Warp or Kuwahara

Both tried on the same frame (`warp-vs-kuwahara.png`). **The warp is kept.**

- A Kuwahara filter (radius 3, four quadrants, 64 screen taps per pixel) gives a smooth oil-paint look: rounded corners, simplified windows. But every edge stays clean. The reference's edges are not rounded, they are ragged, so it misses the thing Roni pointed at. It is also about 20 times the taps of the warp (3), too many for a laptop iGPU at DPR 2.
- The warp keeps shapes crisp and only roughs up their borders. Its price is that it also roughs up every inner colour border, so small details (the windows) look hand-cut. That is wanted here, but at `amount` 0.045 or `haze` 0.7 they turn into concentric ghost rings.

## Rejected: borrowing the nearest surface's noise

A ground pixel next to the building reads noise from the ground behind it, so as the camera orbits, the far side of a silhouette picks up noise from different ground points. I tried letting a pixel take the noise position of the nearest of four depth taps 8 px away, so both sides of a silhouette share the building's noise. It made recessed details (windows) borrow their wall's noise and broke them into rings, so it is off and the code is gone.

## Motion

Judged on 60 captured frames at the base's 20°/s (`motion-before-after.gif`, left warp off, right on) and measured against the same scene with `amount` 0:

- Pixels that change by more than 24/255 between frames: 0.18% per frame with the haze, 0.36% without. Mean absolute change per frame: 0.139 against 0.165. The haze does not add flicker by this measure; softening the borders makes them change less per frame.
- Static on purpose. No time input, so nothing boils. I did not try updating the noise a few times a second: a static field cannot tire the eyes more than a changing one, and the reference is a still.
- Because the noise is on the world, the ragged edge of a shadow stays on the ground and a ragged edge on the building stays on the building. The one place that still crawls is the ground side of a silhouette, which takes the noise of whatever ground is behind it. I can't watch the GIF as a person would, so "calm enough" is for Roni to judge.

## Web (WebGL 2, Compatibility)

Exported (preview build) and run in Chromium on SwiftShader at DPR 1 and 2: renders like the desktop capture, no errors beyond the expected missing LimboConsole.

- Needs `hint_screen_texture` and `hint_depth_texture`, both fine in Compatibility. No other post effect.
- Hash noise is `fract` arithmetic with no `sin`, so it matches across GPUs. The three reads and the noise are plain ALU: 4 value-noise lookups (8 hashes each) and 3 screen taps per pixel, one depth tap. Not measured on a real GPU.
- MSAA smooths geometry edges before the pass; the pass then displaces them, so the haze, not MSAA, decides how the border looks.

## Limits and things not done

- The haze is on every colour border, shadows and tone changes included. It cannot be told to leave one alone (a UI drawn in the 3D view would be hazed too).
- The reference's tree and bush edges are ragged leaf clumps with a tonal pattern inside; this scene has only a building, a sphere and a ground, so the look reads mostly on shadows and the horizon. It needs foliage-like models to show what it does best.
- The reference's flat colour is slightly broken up with soft light pools and gradients overlaying the flat patches. Not done.
- At the far side of the 40 m ground the world-space noise is below a pixel, so the horizon gets almost no haze.
