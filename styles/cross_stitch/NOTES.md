# Cross stitch

Scene: `cross_stitch.tscn` (inherits `styles/style_base.tscn`). Blue thread on white aida cloth: dark thread outlines, a lighter half-filled shade, every stitch an X. Reference: a cross-stitch pattern of a house (outlines, a lighter shaded wall, text-like chunky pixels).

## Technique

One full-screen pass, `cross_stitch.gdshader`, on a 2×2 quad under the camera (the same set-up as sharp-lines' `edge_pass`). The subject materials stay the base's own.

- **The cloth is the screen.** The screen is cut into square cells, `rows` of them from top to bottom (default 80), with the size rounded to whole pixels so stitches stay crisp at any window size or pixel ratio (checked at DPR 1 and 2). The grid is centred, and the weave is drawn in every cell: a hole at each corner and a faint line along each border.
- **What a cell stitches** comes from the scene under it: the average brightness of nine taps of the screen texture, and a depth test against its four neighbours.
  - Dark thread: a silhouette cell, or tone below `dark_fill`.
  - Light thread, filled: tone below `full_fill`.
  - Light thread, half-filled: tone below `half_fill`, on a checkerboard of cells.
  - Nothing: bare cloth.
- **Outlines** come from the depth buffer. 1/depth is a straight line across a flat surface, so its second difference in a cell grid step is 0 there and negative where a neighbour drops away behind the cell. Only the nearer cell of a silhouette is marked, so the outline is one stitch thick like the reference. `edge_max_depth` stops the far horizon getting a stitched line.
- **A stitch** is two capsule strands crossing corner to corner, the second over the first (the under strand is a little darker), with a small per-cell brightness variation so it looks hand-worked.
- Light energies: base sun 0.35 / ambient 0.5. The shader reads tone off the screen, so it only needs the light and shade to be far enough apart to land in different bands.
- This scene's camera is closer (fov 28 instead of 40) and its ground is 400 m, so the subjects take enough cells to read and the ground's edge isn't in frame.

## Web (WebGL 2, Compatibility)

Exported and run in Chromium on SwiftShader at DPR 1 and 2: it renders like the desktop capture, with only the expected missing-LimboConsole errors in the log.

- Needs `hint_screen_texture` and `hint_depth_texture`, both fine in Compatibility. No other post effect.
- Everything inside a cell is shader work, so MSAA doesn't touch it. The X edges are antialiased by hand (`aa` is a fraction of a pixel in cell units).
- Outlines rely on depth precision. 1/depth differences are tiny on far flat ground, and the threshold (0.12) and `edge_max_depth` (40 m) are tuned for this scene's 400 m ground. A bigger scene may need both retuned.

## Motion

Screen-space patterns tired Roni's eyes in the Moebius style, so this was judged in motion (60 captured frames at the base's 20°/s orbit, `motion-before-after.gif` next to the screenshots).

- The thing a screen-fixed pattern does wrong is slide a texture under a moving surface. Here the cloth is supposed to be fixed to the screen and the work is supposed to be made of whole stitches, so nothing slides inside a region. What moves is the boundary of each region, one whole stitch at a time, like any low-resolution pixel render.
- Measured on those frames: about 2.6% of the stitched cells change state per frame (about 49 of 1900), nearly all along silhouettes and tone borders. A screen-fixed checkerboard under the sphere's half-filled band is the one place where a pattern does slide, but it is a low-contrast stitch, not an ink line.
- **Texel snapping does not help.** The trick (snap the camera to the low-res grid and shift the image by the remainder) removes crawl when the camera translates. An orbit rotates the scene, so each stitch's contents change genuinely and no snap can hold them.
- Tried against the flips: spreading the tone taps over 1.5 and 2 cells (`tone_spread`) changed the flip rate by less than 5%, so the default stays at 1; the flips are edges, not texture noise. Flattening the building's material cut flips by about half only because most of its stitches disappeared.
- What changes the amount of crawl is the cell size: at 20°/s the flips per second drop roughly as 1/cell². Rows 96, 80 and 72 gave about 67, 49 and 41 flips per frame. Rows 80 was picked as the chunkiest size that still reads the building's windows.
- I can't watch the GIF as a person would, so "calm enough" is for Roni to judge. If it still tires the eyes, raise the cell size first (`rows` 56 to 64).

## Cost

One full-screen fragment pass: 9 screen taps and 5 depth taps (each with an inverse projection), done for every pixel although the answer is per cell. A pass that wrote to a low-res target and magnified it would do the taps once per cell. Not measured on a real GPU; SwiftShader numbers only compare cost between pieces.

## Limits and things not done

- Tone-based, not region-based: the model's own colours leak in (the Kenney window details become single dark stitches), and a wall and its shadow on the ground are one stitched patch, because they touch and have no depth edge between them.
- Concave creases (a wall meeting the ground) are not outlined. A positive second difference also fires on the far side of every silhouette, which doubled the outlines to two stitches; telling the two apart needs more taps.
- Threads are two flat colours. No floss twist, no backstitch, no letters.
- The pass reads the camera's depth, so it covers anything in the 3D view, UI drawn on top is not stitched.
