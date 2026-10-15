# Web constraints

The game ships as a web build on itch.io, and **web wins** over visual ambition: when an effect doesn't work on the web, drop it. Read this before touching shaders, the environment, lighting, loading or audio.

Facts are for Godot 4.7.2. Sources are listed at the end.

## Renderer

The web runs only the **Compatibility** renderer (WebGL 2). There is no WebGPU, so no Forward+ or Mobile on the web. The whole project uses Compatibility, so the editor shows what players get.

**Works on the web, and builds the soft look:**

- Tonemap **AgX** (or Filmic). Adjustments and a 3D LUT for a pastel grade.
- Ambient light from the sky or a constant pastel colour.
- **SSAO**: only Radius and Intensity apply.
- **Glow**, simplified: Screen blend only, with a low threshold for soft bloom on emissives.
- **Depth and height fog**, with Sun Scatter.
- One shadowed DirectionalLight with soft PCF filtering, plus a few unshadowed omni lights. The limit is 8 omni and 8 spot lights per mesh.
- **Toon** diffuse in StandardMaterial3D, or a custom `light()` ramp in a spatial shader.
- Outlines with **Grow** on an unshaded next-pass material (Cull Front), or the Outline stencil mode. Both need smooth-shaded, connected meshes.
- **MSAA 3D**, the only edge antialiasing on the web.
- Baked **LightmapGI** renders, but baking needs a Vulkan, D3D12 or Metal GPU: bake in the editor on a dev machine. CI can't bake.

**Missing on the web:** volumetric fog and FogVolume (fake local mist with quad sprites), SSR, SSIL, SDFGI, VoxelGI, DOF, auto exposure, decals, debanding, FXAA/SMAA/TAA, textured area lights, the normal-roughness buffer (so no normal-based screen-space edges), compute shaders and CompositorEffects.

**Costs to plan for:**

- Each post effect (glow, SSAO, adjustments) adds a full-screen pass. Test on a laptop iGPU in a browser.
- Fog and gradients band, because there is no debanding. Add dither or noise in materials.
- Shaders compile the first time they're seen, which stutters. Show every material for one frame while the screen is black after a scene change.
- `vertex_color_is_srgb` does nothing in Compatibility. Check vertex-coloured models in the engine.
- **A shadowed light is added in sRGB, so ambient plus a shadowed sun blows out to white.** Compatibility draws ambient and every unshadowed light (directional, omni, spot) in one pass and converts the result to sRGB. Each shadowed light gets its own additive pass that is converted to sRGB too, then added on top ([`scene.glsl`](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/scene.glsl#L3065-L3072), [`rasterizer_scene_gles3.cpp`](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_scene_gles3.cpp#L1346-L1398)). Two encoded values add up far faster than two linear ones, so the defaults (sun energy 1, ambient energy 1) clip a light surface to white. It is the renderer, not `check.py capture`: a plain viewport read and the Web build show the same frame. With no ambient there is nothing to clip, which is why a scene without a `WorldEnvironment` looked fine. Start a shadowed scene at sun energy about 0.35 and ambient about 0.5 and adjust by eye (`styles/style_base.tscn`); the style scenes below needed anything from 0.012 to 0.35. A shadowed and an unshadowed light of the same energy do not match.

**Particles:**

- Work: GPU particles with sphere, box and heightfield colliders, and sphere and box attractors.
- Missing: sub-emitters, `emit_particle()`, particle trails, SDF colliders and vector-field attractors. Godot skips them with a one-time editor warning ([emit_particle](https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html#class-gpuparticles3d-method-emit-particle), [renderer comparison](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#feature-comparison), [GLES3 source](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/storage/particles_storage.cpp#L387)).
- Turbulence has a high GPU cost; the docs advise leaving it off for the web ([turbulence_enabled](https://docs.godotengine.org/en/4.7/classes/class_particleprocessmaterial.html#class-particleprocessmaterial-property-turbulence-enabled)).

**Shader comments are `//`.** In a `.gdshader`, `#` starts a preprocessor directive ([Shader preprocessor](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shader_preprocessor.html)). A `#` comment line before `shader_type` makes Godot drop the `shader_type` without an error, so a particles shader loads as spatial (seen on 4.7.2). Shader samples found online often open with `#` comment lines; turn them into `//` when pasting.

## Export

- Single-threaded build (`variant/thread_support=false`), no PWA, exported as `index.html`. Leave itch's SharedArrayBuffer option off.
- Every machine needs the **4.7.2** Web export templates. Templates from another version fail.
- Expect about 10 MB of engine download plus the `.pck`. itch gzips the files itself.
- The single-threaded build runs everything on the main thread: `load_threaded_request` blocks, so a loading bar would jump from 0 to 1. Load while the screen is black.
- The game pauses while its browser tab is hidden.

## Audio

- Browsers start audio only after a click or key press. On itch, Chrome counts the Run game click, but Safari waits for a click inside the game. Start music in response to the player's first click (the web title card); never at boot.
- Web audio uses **Sample** playback. Bus effects (reverb, filters), procedural audio and reliable positional audio are unavailable. Bus volume and mute work.

## Saving

- `user://` is stored in the browser's IndexedDB, written in the frame after a file is **closed**. Closing the tab triggers no save.
- Save on every change, never on quit: write with `ConfigFile.save()` or a `FileAccess` you close.
- Saves are best effort. Incognito mode, blocked third-party storage (itch runs the game in an iframe) or a change of hosting domain loses them. When `OS.is_userfs_persistent()` is false, keep going for the session.

## Fullscreen and pointer

- itch's embed fullscreen button handles fullscreen.
- In browser fullscreen, Esc only leaves fullscreen. The game never receives it, so Esc can't open the pause menu there.
- Fullscreen and mouse capture work only when requested inside an input event, such as a `Button` press.
- The stretch mode is `canvas_items` with `expand` at 1152×648, so UI scales in fullscreen and mouse-motion `relative` stays in content units.

## Style test findings

Six style scenes inherit `styles/style_base.tscn`, and each has a `NOTES.md` with its technique, web status and cost. They were checked in a Chromium web export on software WebGL 2 (SwiftShader), not on a real GPU or in Safari, so the frame rates there only show how much each piece costs relative to the others.

| Style | Scene | Needs on the web | Light energies (sun / ambient) |
|---|---|---|---|
| Kenney gradient | [`kenney_gradient`](../styles/kenney_gradient/NOTES.md) | Palette texture, wrapped-Lambert `light()`. No post effects. | 0.12 / 0.56 |
| Moebius hatching | [`moebius`](../styles/moebius/NOTES.md) | Hatching in `light()`, inverted-hull outline. No post effects. | sun colour ignored / 0 |
| Soft flat | [`soft_flat`](../styles/soft_flat/NOTES.md) | Banded `light()`, inverted-hull outline, procedural ground. | 0.35 / 0.36 |
| Sharp lines, flat city | [`sharp_lines`](../styles/sharp_lines/NOTES.md) | Banded `light()`, full-screen depth-edge pass (`hint_depth_texture`), or hulls. | 0.012 / 0.72 |
| Cosy glow | [`cosy_glow`](../styles/cosy_glow/NOTES.md) | Glow, fog, filmic tonemap, fake light quads, a vignette. | 0.25 / 0.42 |
| Flat shadows | [`flat_shadows`](../styles/flat_shadows/NOTES.md) | One `light()` that turns the shadow term into a flat tint. | 0.35, colour ignored / white at 1 |

What carried across styles:

- **The sRGB-add rule decides the light setup.** A custom `light()` that ignores the light's colour and energy (moebius, flat shadows) avoids tuning altogether, but it needs the ambient to match: 0 for moebius so ink isn't lightened, white at 1 for flat shadows so the base pass leaves the albedo alone. Flat shadows can only brighten a surface, so each channel of the shadow colour must be at most the lit colour's.
- **Glow is the costly piece.** It added a full-screen buffer and a blur chain and took about a quarter of the frame time in cosy glow's test, against about 14% for fog and about 2% for a vignette pass. Check it on a laptop iGPU before keeping it.
- **Depth fog and the shadowed sun disagree.** Kenney gradient saw a bright band halfway to the horizon when fog was on, so it matches the background colour to the ground by hand. Cosy glow's fog worked with a dim sun. If fog is part of a style, check the ground at the horizon with your own light energies.
- **Additive fakes** (light cones, pools, halos): add `fog_disabled` to their `render_mode`, or fog colour paints the whole quad. Keep dither small: `1/255` added to a dark linear value is clearly visible after the sRGB conversion, so cosy glow uses `1/1024` in its opaque shaders and none in the additive ones. Quads with noise alpha did not work as mist, so use depth fog for haze.
- **Outlines.** Inverted hulls need smooth, connected normals: clean on the sphere and the rounded cube, gaps at the corners of a hard-edged box, and no creases inside a mesh. A depth-edge post pass draws creases and silhouettes in one pass and works on the web (`hint_depth_texture` is available), but in perspective it also fires on curved surfaces. Normal-based edges are not possible, because there is no normal-roughness buffer.
- **Shadow edges.** With the default 100 m shadow distance, a hard-thresholded shadow edge stair-steps. An orthogonal shadow mode with `directional_shadow_max_distance` around 14 helped in flat shadows. MSAA doesn't smooth a threshold inside a shader.
- **Screen-space lines** (hatching) are in framebuffer pixels, so they get finer on a HiDPI canvas. World-space lines stick to the objects but change weight with distance and clump where a surface runs parallel to them.
- **Models matter more than the renderer for most of these looks.** Flat shadows, soft flat, Kenney gradient and cosy glow all depend on authored faces, colours or painted textures that a cube and a sphere don't show.

## Still unverified in a browser

Check these before relying on them: stencil outlines on WebGL 2, saves inside the itch iframe in Safari (they survive a reload in Windows browsers), and whether 3D at full resolution in fullscreen is too slow on HiDPI laptops. Also open: whether to turn on MSAA 3D (off project-wide, so every shader-drawn edge and outline aliases; undecided), glow and the full-screen depth-edge pass on a real iGPU, and every style scene in Safari.

## Sources

Godot documentation is the `4.7` branch; engine source is the `4.7.2-stable` tag.

**Renderer**

- [Renderers: overall and feature comparison](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#overall-comparison) — what Compatibility has and lacks, and its low base cost with high scaling cost.
- [Web export: WebGL version](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#webgl-version) — WebGL 2 only, no WebGPU, and Safari's WebGL 2 problems.
- [Environment and post-processing](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html#glow) — glow, SSAO (Radius and Intensity only) and adjustments.
- [Lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html) — shadowed lights render in sRGB; [`max_lights_per_object`](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-rendering-limits-opengl-max-lights-per-object) sets the 8-omni, 8-spot per-mesh limit.
- [StandardMaterial3D: diffuse mode](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#diffuse-mode) and [stencil](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html#stencil) — Toon shading, Grow outlines and the Outline stencil mode.
- [Volumetric fog](https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html#faking-volumetric-fog-using-quads) — faking local mist with quads.
- [3D rendering limitations: color banding](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html#color-banding) — no debanding, so add dither or noise.
- [3D antialiasing](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_antialiasing.html) — MSAA is the only edge antialiasing.
- [Renderers: global illumination](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#global-illumination) — LightmapGI renders in Compatibility, but baking needs a RenderingDevice GPU.
- [`BaseMaterial3D.vertex_color_is_srgb`](https://docs.godotengine.org/en/4.7/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb) — no effect in Compatibility.
- [Pipeline compilations](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html) — no ubershaders, so show materials for a frame while loading.
- [`rasterizer_scene_gles3.cpp#L2420`](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_scene_gles3.cpp#L2420) — glow, SSAO or adjustments switch Compatibility to an extra buffer plus a post pass.

**Export**

- [Web export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html) — single-threaded is the default and suits itch.io; threaded builds need COOP/COEP headers; export as `index.html`.
- [`export_plugin.cpp#L375`](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/export/export_plugin.cpp#L375) — `variant/thread_support` defaults to `false` and selects the `nothreads` templates.
- [Godot 4.7 release notes](https://godotengine.org/releases/4.7/) — per-platform export templates, which must match the engine version exactly.
- [Serving the files](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#serving-the-files) and [itch.io HTML5 docs](https://itch.io/docs/creators/html5) — gzip (itch's CDN applies it) and itch's file-count and size limits.
- [itch.io forum: experimental SharedArrayBuffer support](https://itch.io/t/2025776/experimental-sharedarraybuffer-support) — the option sets COOP/COEP, moves games to another domain and still opens a popup in Safari.
- [Background processing](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#background-processing) — the game pauses while its tab is hidden.

**Audio**

- [Web export: audio playback](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#audio-playback) — Sample playback has no bus effects, procedural audio or reliable positional audio.
- [Web export: audio](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#audio) — browsers block autoplay, so ask for a click first. Whether itch's own Run game click counts is a browser-by-browser test, not a documented fact.

**Saving**

- [Using cookies for data persistence](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence) — `user://` needs IndexedDB, third-party storage must be allowed in an iframe, and `OS.is_userfs_persistent()` can give false positives.
- [`os_web.cpp#L227-L243`](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/os_web.cpp#L227-L243) and [`library_godot_os.js#L255-L270`](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_os.js#L255-L270) — closing a written file queues a sync for the next main-loop iteration, and only an engine-initiated quit flushes, so closing the tab saves nothing.

**Fullscreen and pointer**

- [Full screen and mouse capture](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html#full-screen-and-mouse-capture) — both must be requested from inside an input event.
