# Sharp lines, flat city

Near-white faces, thin dark ink on every edge, bright background, an isometric camera. The reference is a snow-white isometric town.

| Scene | What it shows |
|---|---|
| `sharp_lines.tscn` | The main one. Orthographic 35 degree camera, depth-edge post pass. |
| `sharp_lines_perspective.tscn` | The same with a perspective camera. |
| `sharp_lines_hull.tscn` | Orthographic, but with inverted-hull outlines instead of the post pass. |

All three inherit `styles/style_base.tscn` and add a small `Town` of hard-edged boxes and a roof. The base's rounded cube and sphere have no creases, so on their own they can't show this style.

## Technique

**Faces** (`flat_face.gdshader`): a `light()` that gives each face one of three hard bands from the sun's angle (top, front and side faces get their own tone) and nothing smooth in between. Ambient does the rest. A faint tile grid on the ground comes from the same shader (`grid_strength`).

**Lines, post pass** (`edge_pass.gdshader`): a 2x2 `QuadMesh` under the camera, `POSITION` forced to fill the screen, reading `hint_depth_texture`. Each pixel takes the second difference of depth against its four neighbours (`line_px` away). A flat face gives 0 whatever its angle, a crease gives a spike, a silhouette gives a huge one, so a single pass draws outlines and hard edges. It writes `ALPHA` with normal blending, so it never reads the screen texture (no sRGB mixing to get wrong). Orthographic uses depth, perspective uses 1/depth, both linear on screen.

**Lines, inverted hull** (`outline_hull.gdshader`): the `next_pass` of the face material, back faces pushed out along the normal by a fixed number of pixels.

## What works and breaks

| | Post pass | Inverted hull |
|---|---|---|
| Silhouette | yes | yes |
| Crease lines inside an object | yes, the point of it | no |
| Hard-edged meshes (box, prism) | clean | gaps at every corner, because box normals are split |
| Smooth meshes (sphere, rounded cube) | a line where the curve is steep, plus noise from depth steps | clean silhouette |
| Line width | `line_px`, same everywhere | `line_px`, same everywhere |
| Antialiasing | soft threshold only | MSAA works on the hull |
| Extra cost | one full-screen pass with 5 depth reads, and a depth copy | one more draw of every outlined mesh |

- **Web**: the post pass runs in the Web build (checked in Chromium on WebGL 2, SwiftShader, software GL only). `hint_depth_texture` works in Compatibility. The normal-roughness buffer doesn't exist there, so normal-based edge detection isn't an option; the second difference of depth stands in for it.
- **Orthographic matters.** The ortho scene is clean at `threshold` 0.7. In perspective the same measure also fires on curved surfaces, so `edge_pass_perspective.tres` uses 0.3, and the sphere still shows a faint mesh pattern at its steep edge. Edge strength cannot tell a smooth curve from a crease, only how strong it is. A sharp-lined look wants hard-edged models.
- **Lighting**: ambient 0.72 and sun 0.012. A shadowed sun is added in sRGB in Compatibility, so even 0.05 clips the top faces to white; see `docs/web-constraints.md`. The three bands are tuned by eye.
- **Shadows** are the base's soft PCF shadow, so they read grey and soft, not flat. The reference has almost none.
- **No lines on shadows or the ground grid**: lines come from depth, and shadows and the tile texture have none.

## Cost, roughly

Not measured on hardware. Post pass: one full-screen fragment pass with 5 texture reads, plus the depth copy Compatibility makes when a material uses `hint_depth_texture`. Hull: one extra draw of each mesh, which grows with object count rather than screen size. Check both on a laptop iGPU in a browser before choosing.

## Tuning

`threshold` and `line_px` in `edge_pass.tres`, `line_px` and `line_color` in `outline_hull.tres`, `band_edges` and `lit_strength` in `flat_face.gdshader`.
