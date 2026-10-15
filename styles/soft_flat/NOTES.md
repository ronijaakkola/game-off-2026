# Soft flat

Style 3 of the rendering comparison: near-flat shading, muted greens and reds, thin dark outlines, and a painted look on the ground. Reference: white walls with red roofs on a green island, from a hand-drawn game. Open `soft_flat.tscn`; it inherits `styles/style_base.tscn` and only overrides the environment and three materials.

## Technique

- **Light ramp** (`soft_flat_light.gdshaderinc`, used by the subject and ground shaders): a custom `light()` turns `dot(NORMAL, LIGHT)` into three bands (ambient only, mid, lit) with soft `smoothstep` edges. The shadow term goes through a `smoothstep` on `ATTENUATION`, so the cast shadow is a flat, slightly soft patch. The dark band is only the ambient light, so the ambient colour sets the shade tint.
- **Subjects** (`soft_flat_subject.gdshader`): a colour that darkens toward the ground by world height (the grey wall foot in the reference), and a second colour on upward-facing surfaces (the red roof on the cube, off for the sphere).
- **Ground** (`soft_flat_ground.gdshader`): procedural value noise in world space, no textures. Two soft washes (lighter and darker green) are turned into ragged dry-brush edges by finer noise (`brush_edge`). The fine noise fades out with distance so it doesn't shimmer.
- **Outline** (`soft_flat_outline.gdshader`): a `next_pass` on the subject materials. An inverted hull with front faces culled, pushed outward in clip space so it stays 1.5 px wide at any distance. It needs smooth, connected normals, which the sphere has. On the base's Kenney building the hull is thin and broken: the capture shows no clear outline on the silhouette, only dark slivers behind window frames and ledges. The ground has none.
- **Environment**: constant cool ambient, a muted blue-grey background standing in for the water, no tonemap, glow or SSAO.

## Web (WebGL 2)

Checked in Chromium with software WebGL 2 on the Web Preview export: it renders the same as the desktop capture.

- Works: custom `light()`, `#include` of a `.gdshaderinc`, `POSITION` override in the outline shader, `VIEWPORT_SIZE`, `next_pass`, shadow `ATTENUATION`.
- The light ramp is tuned for the Compatibility sRGB add of the shadowed sun (ambient 0.36, sun 0.35, `light_strength` 0.7). More ambient or sun clips the white cube to flat white and the bands vanish. See `docs/web-constraints.md`.
- The outline is only antialiased by MSAA 3D, a project setting that is now 4x. At 1.5 px the edge stair-stepped with it off; with it on the hull outline is smooth.
- The ground's view distance is computed in `fragment()`. A varying set in `vertex()` on the base's two-triangle ground plane interpolates the four far corners and is wrong almost everywhere.

## Cost

- Two draw calls per outlined subject (surface plus hull), one for the ground. No post-processing and no extra passes beyond the shadowed sun the base already has.
- The ground shader runs five value-noise lookups per fragment on a plane that fills most of the screen. That is the one thing worth measuring on a laptop iGPU; if it costs too much, bake the washes to a texture.

## Limits and what differs from the reference

- The reference has painted, vertically streaked grass blades. This has ragged edges in every direction, since a streak direction in world space would rotate against the orbiting camera.
- The reference's thin outlines also cover the ground edge and cliffs; the base has a flat plane, so those aren't shown.
- The ground and subjects share one ramp, so a cast shadow can disappear into a dark patch. The patches are fixed in world space; change `patch_scale` or the noise offsets to move them.
