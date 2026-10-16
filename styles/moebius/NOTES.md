# Moebius: drawn outlines and hatching

Scene: `moebius.tscn` (inherits `styles/style_base.tscn`). Style 2 of the rendering comparison.
Reference: flat pastel fills, inked outlines, hatching in shade, cross-hatched cast shadows.

## Technique

- **Fill**: a flat colour per material (`fill`), no gradient, no specular beyond one stylised highlight on the sphere.
- **Hatching** (`moebius_ink.gdshader`): done inside `light()`. The tone is `N·L × shadow attenuation`, so the dark side of a form and a cast shadow on the ground use the same rule. Below `light_edge` one family of diagonal lines is drawn, below `dark_edge` a second family crosses it. The shader writes the lit result as `mix(1, ink_floor, ink)`, so lines are the fill pulled to near black and the gaps are the plain fill.
- **Line space**: strokes are pinned to the surface, so they move with it when the camera moves. Hard and flat surfaces use triplanar mapping in object space (`line_spacing` in mesh units): each axis plane draws its own diagonal hatch, weighted by how squarely the surface faces it (`projection_sharpness`). The sphere uses `uv_hatching`: strokes follow its UV parallels and meridians, so they wrap the form like engraving. Triplanar on a sphere gave a patchwork of three directions, which is why it has its own mode. Moire is damped by fading dense lines to their average coverage (`fwidth`).
- **Rejected: screen-space hatching.** Lines laid out in screen pixels keep a perfect weight, but the pattern stays still while surfaces slide under it (the "shower door" effect). Roni found it tiring to watch while the camera orbits. Plain world-space slicing planes were also tried: they clump into blobs where a surface runs parallel to the planes.
- **Outline** (`moebius_outline.gdshader`): inverted hull as the `next_pass` of the subject materials, pushed out along the normal by a fixed `width_px` in clip space, so line weight is constant on screen. A small sine on world position varies the weight along a form. The ground has no outline.
- **Hand-drawn strokes**: every hatch line is its own stroke, seeded by its index. It sits off the grid (`spacing_jitter`), wanders sideways along its length (`waver`), swells and thins (`line_variation`) and stops at its own tone (`end_jitter`), so the edge of a hatched area is ragged instead of a clean curve. All from cheap hash and value-noise functions, no textures. The outline's weight swells and thins with world position (`weight_variation`). Both are static: nothing boils or animates.
- **Environment**: overridden in this scene only. Ambient energy is 0 (see below) and the sky is a flat lavender/teal procedural sky.

## Web (WebGL 2, Compatibility)

Checked in Chromium with SwiftShader against the preview export: the hatching, shadows, highlight and outlines render like the desktop capture.

- Everything is regular spatial shaders: no screen texture, depth texture or post pass. Nothing here needs a feature the Compatibility renderer lacks.
- The ink shader **ignores the sun's colour and energy** and only reads its direction and shadow. It also needs **ambient at 0**, because ambient is added as fill colour and would lighten the ink. With one shadowed light and no ambient, the sRGB-add clipping in `docs/web-constraints.md` doesn't apply.
- The hatch lines are shader work, not geometry, and edges inside the shader (line edges, the tone thresholds) are not covered by MSAA. They are antialiased with `fwidth`. Outline silhouettes do get MSAA when it is on.
- Pinned strokes change weight with distance and get dense where a surface turns away from the camera. The fade to average coverage keeps that from shimmering at the fixed orbit distance; a game with a zooming camera would need `line_spacing` tuned for its closest and farthest views.
- `uv_hatching` needs continuous UVs. Kenney models use palette-atlas UVs, so they use triplanar.
- The outline needs smooth, connected meshes. The sphere is. A hard-edged cube would break into separate hulls at the corners. The base's Kenney building has bevelled edges and the outline holds up well on it (checked in a capture): the silhouette is closed, the hatching follows the bevels, and only a few short gaps show at the sharpest corners. The model's colours are ignored; the ink shader paints one fill.

## Cost

- Outline: one extra draw of each outlined mesh, back faces only. Cheap for a few objects, doubles vertex work for the subjects.
- Ink shader: triplanar draws six stroke families per fragment (three planes × two directions), each a few hash and noise lookups. That is the heaviest part of this style, but still one light pass with no full-screen pass. The UV path draws two.
- Shaders compile on first use: show the materials for a frame behind a black screen on scene change (see `docs/web-constraints.md`).

## Limits and things not done

- Only one shadowed light is supported by this approach: a second one would add its own hatching pass, and the lights would sum in sRGB.
- No texture detail in the fill (the reference has cracked-brick texture); that would be a texture on `fill`.
- The horizon is a flat lavender band: with the base camera the sky above the horizon is out of frame, so the reference's teal-to-purple sky gradient can't show without a camera change.
