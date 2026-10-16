# Flat shadows

Fully flat colour with cast shadows drawn as one flat tint. Scene: `styles/flat_shadows/flat_shadows.tscn` (inherits `style_base.tscn`). Shader: `flat_shadow.gdshader`.

## Technique

- Every surface has two colours: `lit_color` where the sun reaches it, `shadow_color` where it doesn't. Nothing else shades it: no ramp, no specular, no ambient variation.
- "Doesn't reach" means the cast shadow of another mesh, or a face turned away from the sun, so the terminator on the sphere and the cube's dark faces use the same tint as the ground shadow.
- The shadow term comes from `ATTENUATION` in `light()`. A smoothstep around 0.5 snaps the soft PCF result to a hard edge (`edge_threshold`, `edge_width`).
- `face_value` multiplies both colours by a constant per world axis (up, X, Z), a stand-in for the authored per-face colours in the reference. Material values are 1.0 on the sphere and on the ground.
- The environment is a flat background colour with white ambient at energy 1. The sun stays at the base's 0.35; its energy doesn't change the look because the shader ignores the light colour.
- `directional_shadow_mode = 0` (orthogonal) and `directional_shadow_max_distance = 14` on the Sun, set in this scene only. Left at the defaults, the shadow map spans 100 m and the shadow edges stair-step visibly.

## What the colours must obey

How Compatibility composes a shadowed light, measured here by reading pixels, not taken from the docs:

- The base pass writes `ALBEDO` to the screen as it is. Ambient white at energy 1 leaves it untouched, so the base pass paints `shadow_color`.
- The shadowed sun is a second pass: `DIFFUSE_LIGHT * linear(albedo)`, encoded to sRGB, added on top. In `light()`, `ALBEDO` already reads linear. So `DIFFUSE_LIGHT = linear(lit - shadow) / ALBEDO` lands exactly on `lit_color` in the lit area (ground checked: set (0.98, 0.9, 0.75), read back (250, 230, 191) native and in the browser).
- **Adding can only brighten, so every channel of `shadow_color` must be <= the same channel of `lit_color`.** That is the real limit of this technique. The reference's lavender shadow on a cream ground (shadow bluer than the lit surface) is not reachable; the closest here is a mauve-lavender (153, 133, 191) on cream (250, 230, 191). Making it work would need a multiplicative pass, which the shadow term can't drive.
- Very dark shadow colours quantise a few levels off (shadow 0.1 gave 227 where 230 was set).

## On the web (WebGL 2)

Exported with the preview build and loaded in Chromium with software WebGL 2: the frame matches the native capture to the pixel on flat areas, and the shadow edges look the same. Not run on a real GPU or in Safari.

- Works: hard cast shadows with a flat tint, self-shadowing on the sphere and cube, no acne or peter-panning at the base's default bias.
- Edge aliasing: the shadow edge is a hard threshold of a shadow-map lookup, so it is jagged where texels show. Tightening the shadow distance as above helps; MSAA 3D doesn't smooth it. Expect crawling edges on a moving sun.
- Breaks if you add post effects: glow, tonemapping and adjustments move Compatibility to a linear HDR buffer, where the base and light conversions differ. The constants here were measured without them.
- One shadowed sun only. Each extra shadowed light would add its own `gain`, and unshadowed or omni lights have no shadow term to key on.

## Cost

One shadow map and, per mesh, two draw passes (base + sun). That is the same as any shadowed lit mesh in Compatibility. The shader does a few `pow` calls per fragment in `light()`. No post effects, no extra screen passes. Not measured on a device.

## Honest read

The shader is a small part of this style. The reference gets its depth from authored geometry: every face is its own colour, buildings are cut into slabs, and the shadow tint is the one thing the light adds. The base's building is a Kenney model, and its material turns on `use_albedo_tex`: the lit colour is the model's colormap at its UV and the shadow colour is that times `shadow_tint`, so each face keeps its colour and every shadow shares one tint. The sphere is still a flat disc.
