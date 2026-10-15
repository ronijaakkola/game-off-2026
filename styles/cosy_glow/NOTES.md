# Cosy glow

Style 5 of the rendering test: soft and cosy, a teal dusk with one warm light, after a reference of a vending machine glowing in a back alley. Scene: `cosy_glow.tscn` (inherits `styles/style_base.tscn`). Keys 1 to 4 switch glow, fog, the fake light pieces and the vignette on and off at runtime, so a browser build shows what each one does.

Screenshots are in the project's `style-cosy-glow/` folder, next to the reference.

## What the look is made of

| Piece | Where | Web (WebGL 2) |
|---|---|---|
| Cool ambient, dim cool shadowed sun | `Environment_cosy`, `Sun` | Works. Sun 0.25, ambient 0.42, because a shadowed light adds in sRGB (see `docs/web-constraints.md`). |
| Warm local light | `Machine/Lamp`, an unshadowed `OmniLight3D` | Works. Unshadowed lights go through the main pass, so they don't clip like the sun does. A shadowed omni would. |
| Soft painterly surfaces | `cosy_surface.gdshader` | Works. Vertical colour gradient, blotchy grain from `grain.png`, a wide half-lambert ramp in `light()`, a faint rim. |
| Emissive panel | `cosy_emissive.gdshader` | Works. Unshaded, drawn brighter than 1 so glow picks it up. |
| Glow | `glow_*` in the environment | **Works.** Screen blend, threshold 0.7. The panel and the lit ground bloom. A threshold under about 0.6 blooms every lit surface and washes the scene out. |
| Fog | `fog_*` in the environment | **Works.** Exponential, same colour as the background, so the ground edge melts into the sky. Without it the ground plane shows a hard horizon. |
| Tonemap | Filmic, saturation 1.2 | Works. AgX desaturated the warm light too much. |
| Light shaft | `cosy_light_cone.gdshader` on an open cone | Fake. Additive, fades with height and towards its silhouette. |
| Light pool on the ground | `cosy_pool.gdshader` on a plane | Fake, stands in for a decal. |
| Bloom halo | `cosy_halo.gdshader` on a camera-facing quad | Fake. Always on, fades out as the camera leaves the lit side. |
| Vignette | `cosy_vignette.gdshader` on a `ColorRect` | One canvas pass. |

## What breaks or surprised

- **Fog gets added to additive materials.** An additive fake with fog on picks up the fog colour on its whole quad, so a rectangle of fog colour showed around the pool and the cone. `fog_disabled` in `render_mode` fixes it. Any fake light that is additive needs it.
- **Dither in linear is not 1/255.** A `1/255` dither added to a dark linear value is clearly visible after sRGB conversion, and in an additive pass it lifted the whole quad. The opaque shaders use `1/1024`, the additive ones none. There is no debanding on the web, so the surface shaders keep a little.
- **Fake mist quads didn't work.** Billboarded quads with a noise alpha, laid out near the ground, read as bright blotches or stains against the lit ground, not as mist. Depth fog does the haze job alone, so they are gone. A real local mist needs a depth fade, and the depth texture is not something to lean on in Compatibility.
- **Additive things that wrap geometry paint it.** The cone is wider than the machine at the bottom, so from behind it drew a tan wash with a wavy edge over the machine. `clip_z` drops the part behind the machine's face. The halo has the same problem and is drawn without a depth test, so it fades with the view angle instead. A faint triangle where the cone's wall crosses the machine's side is still visible from some angles.
- Importing or exporting headless prints `_create_mesh_array must return at least a vertex array` for every `RoundedBoxMesh`. It comes from the base scene's mesh script, which isn't a `@tool` script, and the exported build renders it fine.
- A custom `light()` replaces the shadowed sun's own response, so the soft ramp (half-lambert through a smoothstep) is what softens shadow edges, together with `shadow_blur`. It cost nothing extra to run.

## Rough cost

Measured as frames per second in a Chromium web export, switching pieces off with the number keys. The browser ran on a software renderer, so the speed itself means nothing, but the share each piece takes of a fill-rate bound frame is roughly what to expect from a laptop iGPU:

| State | fps | Against all on |
|---|---|---|
| All on | 1.67 | |
| Vignette off | 1.71 | about 2% |
| Fake light off | 1.70 | none you can tell from noise |
| Fog off | 1.97 | about 14% |
| Glow off | 2.44 | about 24% |

Glow is the expensive piece: it adds a full-screen buffer and a blur chain. Fog is per fragment. The fakes are a few transparent quads and cost almost nothing. The two lights and four custom shaders are cheap. Test glow on a real laptop iGPU before keeping it.

## Gaps against the reference

The scene gets the colour mood: teal ambient, a warm emissive source, a warm pool spilling over a pale ground. It doesn't get the drawn look. The reference has flat, hand-painted shapes with brushy outlines and a clear value structure; this scene is smooth-shaded geometry with a noise grain. Getting there needs painted textures on the models, which belong with the models, not the renderer. A second gap is the machine itself: a navy rounded box with a flat glowing panel, no stars or buttons.
