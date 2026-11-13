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
- **Frosted UI**: a `canvas_item` shader reading `hint_screen_texture, filter_linear_mipmap` with `textureLod` sees the screen behind it blurred, each level a Gaussian blur of the one before. `game/solar_system/resource_bar.gdshader` does it (checked in Chromium).
- **Depth and height fog**, with Sun Scatter.
- One shadowed DirectionalLight with soft PCF filtering, plus a few unshadowed omni lights. The limit is 8 omni and 8 spot lights per mesh.
- **Toon** diffuse in StandardMaterial3D, or a two-tone ramp worked out in `fragment()` of an `unshaded` shader (`shared/two_tone_light.gdshaderinc`). Not a custom `light()`: see Costs.
- Outlines with **Grow** on an unshaded next-pass material (Cull Front), or the Outline stencil mode. Both need smooth-shaded, connected meshes.
- **MSAA 3D**, the only edge antialiasing on the web.
- Baked **LightmapGI** renders, but baking needs a Vulkan, D3D12 or Metal GPU: bake in the editor on a dev machine. CI can't bake.

**Missing on the web:** volumetric fog and FogVolume (fake local mist with quad sprites), SSR, SSIL, SDFGI, VoxelGI, DOF, auto exposure, decals, debanding, FXAA/SMAA/TAA, textured area lights, the normal-roughness buffer (so no normal-based screen-space edges), compute shaders and CompositorEffects.

**Costs to plan for:**

- Each post effect (glow, SSAO, adjustments) adds a full-screen pass. Test on a laptop iGPU in a browser.
- Fog and gradients band, because there is no debanding. Add dither or noise in materials.
- Shaders compile the first time they're seen, which stutters. Show every material for one frame while the screen is black after a scene change; `SceneFlow` does it under its loading card, one new material a frame. In Chrome on Windows (ANGLE on Direct3D 11, measured 2026-11-08), a first draw costs about 200 ms per material, and the solar system's first draw was 90 % of its load.
- **A custom `light()` function costs about 1.5 s to compile**, even one that only adds a constant, against about 0.2 s for the same shader `unshaded` (measured as above). Light in `fragment()` instead, as `shared/two_tone_light.gdshaderinc` does. In `light()`, Compatibility also used `source_color` uniforms as stored, without the sRGB to linear conversion `fragment()` gets, so a colour moved out of `light()` needs its value converted to keep its look.
- `vertex_color_is_srgb` does nothing in Compatibility. Check vertex-coloured models in the engine.
- Shadowed lights render in sRGB, so they can look brighter or darker than unshadowed ones. Adjust energy by eye.
- **Don't set Scaling 3D below 1.0 on 4.7.2.** In every browser on Windows, ANGLE upscales the depth-stencil buffer on the CPU, about 6× slower at 4K and worst in fullscreen. Fixed in 4.8 ([godot#119317](https://github.com/godotengine/godot/issues/119317), [PR #124310](https://github.com/godotengine/godot/pull/124310)).

**Particles:**

- Work: GPU particles with sphere, box and heightfield colliders, and sphere and box attractors.
- Missing: sub-emitters, `emit_particle()`, particle trails, SDF colliders and vector-field attractors. Godot skips them with a one-time editor warning ([emit_particle](https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html#class-gpuparticles3d-method-emit-particle), [renderer comparison](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#feature-comparison), [GLES3 source](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/storage/particles_storage.cpp#L387)).
- Turbulence has a high GPU cost; the docs advise leaving it off for the web ([turbulence_enabled](https://docs.godotengine.org/en/4.7/classes/class_particleprocessmaterial.html#class-particleprocessmaterial-property-turbulence-enabled)).

**Shader comments are `//`.** In a `.gdshader`, `#` starts a preprocessor directive ([Shader preprocessor](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shader_preprocessor.html)). A `#` comment line before `shader_type` makes Godot drop the `shader_type` without an error, so a particles shader loads as spatial (seen on 4.7.2). Shader samples found online often open with `#` comment lines; turn them into `//` when pasting. `check.py lint` fails on one.

## Export

- Single-threaded build (`variant/thread_support=false`), no PWA, exported as `index.html`. Leave itch's SharedArrayBuffer option off.
- Every machine needs the **4.7.2** Web export templates. Templates from another version fail.
- Expect about 10 MB of engine download plus the `.pck`. itch gzips the files itself.
- The single-threaded build runs everything on the main thread: `load_threaded_request` blocks, so its progress jumps from 0 to 1. Load while the screen is black. `SceneFlow`'s loading bar moves anyway because it loads the next scene's files itself, everything a file uses before the file, and draws a frame between steps, then draws the scene's materials for the first time one a frame.
- The game pauses while its browser tab is hidden.
- In 4.7.2 the export's text-to-binary resource conversion drops the values of script-exported `PackedStringArray` properties saved in a `.tres`, so exported builds get the script's default. Export string lists as `Array[String]`.

## Audio

- Browsers start audio only after a click or key press. On itch, Chrome counts the Run game click, but Safari waits for a click inside the game. Start music in response to the player's first click (the web title card); never at boot.
- Web audio uses **Sample** playback. Bus effects (reverb, filters), procedural audio and reliable positional audio are unavailable. Bus volume and mute work.

## Saving

- `user://` is stored in the browser's IndexedDB, written in the frame after a file is **closed**. Closing the tab triggers no save.
- Save soon after every change, never only on quit: write with `ConfigFile.save()` or a `FileAccess` you close. For a burst of changes, like a slider drag, save once the burst stops, as `Settings` does.
- Saves are best effort. Incognito mode, blocked third-party storage (itch runs the game in an iframe) or a change of hosting domain loses them. When `OS.is_userfs_persistent()` is false, keep going for the session.

## Online

- Talo's API takes requests from any origin, so the itch iframe can reach it (unverified in a browser until the access key is in). `docs/online.md` has the rest.
- A closed tab sends nothing: queued analytics go out every 15 seconds and when the window loses focus.

## Fullscreen and pointer

- itch's embed fullscreen button handles fullscreen. It fullscreens the game's iframe; the preview build's frame page has the same button.
- In browser fullscreen, Esc only leaves fullscreen. The game never receives it, so the pause menu opens whenever the game's window shrinks instead. Neither the window mode (the iframe is fullscreened from outside) nor a comparison with `screen_get_size()` (a fullscreen area can be smaller than the screen, as under a notch) tells reliably that fullscreen ended.
- Fullscreen and mouse capture work only when requested inside an input event, such as a `Button` press.
- The stretch mode is `canvas_items` with `expand` at 1152×648, so UI scales in fullscreen and mouse-motion `relative` stays in content units.

## Still unverified in a browser

Check these before relying on them: the pause on leaving fullscreen in Firefox, Safari and on itch itself (checked in Chromium only), stencil outlines on WebGL 2 (the bus's hover border relies on them: hover the bus in the preview build), the frosted UI blur in Firefox and Safari, saves inside the itch iframe in Safari (they survive a reload in Windows browsers), and whether 3D at full resolution in fullscreen is too slow on HiDPI screens: Firefox on itch drops to about 40 FPS in fullscreen on a 144 Hz screen that holds 144 everywhere else. The debug panel's Rendering switches and Show FPS are there to find which cost does it.

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
