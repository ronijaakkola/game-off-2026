---
name: blender-models
description: Make or change a 3D model in Blender and export it into the project as a .glb. Use when a feature needs a new model, a model's shape, size, colour or collider changes, or when working in the model library (art/models.blend) through the Blender MCP or `tools/blender.py`.
---

# Blender models

Every model lives in the **model library**, `art/models.blend`: one collection per model, named after its `.glb` (`piece` → `game/models/piece.glb`), side by side with the others and a `reference` collection (a 1 m cube and a 1.7 m person). Only the exported `.glb` is committed. Build to the conventions in `CODING_STANDARDS.md` › Models.

## Live or headless

- **Blender is open with the library** and the `mcp__blender__*` tools answer: work **live** through `execute_blender_code`. The human may be editing the same file, so read the live state before changing anything.
- **Blender is closed**: work **headless** with `uv run tools/blender.py run <script>`. It runs the script against the library and saves it, and creates the library on first use.
- **Blender is open but the MCP tools are missing**: ask the human to save and close the library first. A headless `run` saves the file on disk, and the open Blender would overwrite that on its next save.

`preview` and `export` only read the saved library, so they are safe while Blender is open.

## Building

Write the build code as a throwaway script in your scratchpad, never in the repo. Start it with the helpers in `tools/blender/library.py`. Headless, `run` puts them on the path; live, add `import sys; sys.path.insert(0, "<repo>/tools/blender")` first.

```python
import bmesh
import bpy
import library

piece = library.model("piece", "game/models/piece.glb")  # new: placed beside the others
library.clear(piece)  # rebuilding: start empty

mesh = bpy.data.meshes.new("Piece")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(0.8, 0.8, 0.4), verts=bm.verts)
bmesh.ops.translate(bm, vec=(0, 0, 0.2), verts=bm.verts)  # origin at the bottom centre
bm.to_mesh(mesh)
bm.free()
body = library.add(piece, bpy.data.objects.new("Piece", mesh))  # build at the origin, add() moves it into place
...

bpy.context.view_layer.update()
assert sorted(o.name for o in piece.objects) == ["Piece", "Piece-colonly"]
assert tuple(round(d, 4) for d in body.dimensions) == (0.8, 0.8, 0.4), body.dimensions
```

End every script with asserts on what it built: object names, dimensions, modifier stack, material count. Some operators silently do nothing, and Blender exits 0 anyway, so the asserts are the only proof. A failing assert stops `run` before it saves.

Live, two more rules hold, since edits through the MCP neither mark the file dirty nor make their own undo step:

- End every `execute_blender_code` edit with `bpy.ops.ed.undo_push(message="Agent: <what changed>")`, so the human's Cmd+Z takes back exactly your change.
- Save with `bpy.ops.wm.save_mainfile()` when you finish, and before `preview` or `export`, since both read the file on disk. Otherwise Blender may close without asking and lose your work.

`mcp__blender__jump_to_view3d_object_by_name` shows the human what you changed, and `mcp__blender__get_screenshot_of_window_as_image` shows you what they see.

## Checking and exporting

1. `uv run tools/blender.py preview <model>` renders front, side, top and three-quarter views to `build/preview/<model>.png`. Open it and fix the shape until it's right. Its colours are approximate.
2. `uv run tools/blender.py export <model>` exports the `.glb` with the fixed settings, imports it into Godot, sets any extracted textures to VRAM Compressed, and captures the model in `tools/model_preview.tscn`. Check the facts it prints against the conventions (materials, a `-colonly` node, extensions `none`), then open the capture it names. The capture is the colour check, since Blender and Godot's Compatibility renderer disagree on colour.
3. `uv run tools/check.py load`, then commit the `.glb`, its `.glb.import` and any `<model>_<image>.png` with its `.png.import`.

To use the model in a scene, instance the `.glb` with the uid from its `.glb.import` (the `edit-tscn` skill). When a model's look matters, end the handoff with "Needs a visual check:" and the scene that uses it, or the capture frame if no scene does yet.
