# Kenney gradient

Soft, low-contrast pastel look in the style of Kenney's colormap assets: no texture detail, only flat-ish colours with a gentle gradient, lit by a lot of ambient light and very little sun. Scene: `kenney_gradient.tscn` (inherits `styles/style_base.tscn`).

## Technique

- **Palette texture** (`palette.png`, 128×64). Each column is one swatch, a vertical gradient from a light top to a deeper, bluer bottom. `make_palette.py` writes it; edit the table there or paint the PNG by hand.
- **One shader** (`gradient_palette.gdshader`) for every surface. A material picks a `swatch` (column) and a `v_range` (which rows of it to use). The ground uses a narrow range, so it is nearly flat; the subjects use the whole range, so they fade from light at the top to deep at the bottom.
- The gradient comes from the mesh's UV.y, like Kenney's models. The sphere's UVs do that. The base's building is a Kenney model whose UVs already point into Kenney's own colormap (`styles/models/Textures/colormap.png`, the same layout as `palette.png`), so its material turns on `uv_lookup` and reads the colormap at the mesh's UV: every face keeps the colour the artist gave it. `gradient_from_height` stays as an option for a mesh without usable UVs, such as the rounded box.
- **Soft light**: a custom `light()` with wrapped Lambert (`wrap` 0.5), so the dark side stays well lit instead of going black. It does the same job as Toon diffuse would, without the hard ramp.
- **Environment**: flat lilac background, near-neutral lilac ambient at energy 0.56, sun at 0.12, shadow blur 1.5. No fog, glow, SSAO or tonemap. The background colour is set to equal the lit ground, so the 400 m ground plane melts into it at the horizon.

## WebGL2

- Everything used works in Compatibility: a spatial shader, a texture read, `light()`, one shadowed directional light, a flat environment. No post-processing, so the cost is one texture read per fragment plus the shadow pass. It should be as cheap as the base.
- **Light energies are tuned by the sRGB-add rule** (see `docs/web-constraints.md`): the shadowed sun is added on top of ambient after sRGB conversion. Ambient 0.6 with sun 0.12 already clips the ground's blue channel to 255, hence 0.56. Raise either and the lilac washes out.
- **Fog doesn't work with this setup.** Depth fog fades the ambient pass but not the shadowed sun pass, so the ground turned into a bright band halfway to the horizon. Fading in the shader had the same problem (a dark band). Hence the huge ground plane and a background colour matched by eye. If you change the ground colour or the light energies, re-match `background_color` to the lit ground (read a pixel from a `capture`).
- MSAA 3D is a project setting (`rendering/anti_aliasing/quality/msaa_3d`), now 4x, which this style needs because its look depends on clean silhouettes. It was off when this style was built.
- The shadow terminator on the sphere shows some noise at the default shadow quality.

## What the base scene can't show

The base's building is a real Kenney prop, so the chunky bevelled faces with a swatch each are here. The sphere is still a single swatch, and the building's small details (window frames, roof clutter) are what MSAA and the soft light have to carry.
