---
name: edit-tscn
description: Hand-edit Godot .tscn scenes and .tres resources as text. Use when creating or changing a scene, adding nodes, instancing a sub-scene, wiring an ext_resource or uid:// reference, or resolving a merge conflict in a .tscn or .tres.
---

# Editing .tscn and .tres

You may edit any scene or resource as text, visual properties included. Godot 4.7 normalises the file the next time the editor saves it, so keep edits minimal and in Godot's own shape.

Finish every edit with `uv run tools/check.py load`. It loads every scene and fails on parse errors and missing dependencies. After a visual change, also run `uv run tools/check.py capture <scene>` and look at the frame it names.

## File shape

Sections come in this order: header, `ext_resource`s, `sub_resource`s, nodes, connections.

```
[gd_scene format=3 uid="uid://cmx3l2s0kq7ab"]

[ext_resource type="Script" path="res://ui/main_menu/main_menu.gd" id="1_menu"]
[ext_resource type="PackedScene" path="res://ui/settings/settings_menu.tscn" id="2_sett"]

[sub_resource type="LabelSettings" id="LabelSettings_title"]
font_size = 32

[node name="MainMenu" type="Control" unique_id=1296613593]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_menu")

[node name="Buttons" type="VBoxContainer" parent="."]
layout_mode = 2

[node name="PlayButton" type="Button" parent="Buttons"]
unique_name_in_owner = true
layout_mode = 2
text = "Play"

[node name="SettingsMenu" parent="." instance=ExtResource("2_sett")]
visible = false

[connection signal="pressed" from="Buttons/PlayButton" to="." method="_on_play_button_pressed"]
```

- **Header:** `[gd_scene format=3]`, plus `uid="..."` when the file already has one. Leave out `load_steps`; 4.7 doesn't write it.
- **`parent`:** the root node has none. Its children use `parent="."`, deeper nodes the path from the root (`parent="Buttons"`, `parent="Buttons/Row"`). A node's block comes after its parent's.
- **`id`:** any string unique within the file. Godot writes `1_abcde` for ext_resources and `Type_abcde` for sub_resources; a readable suffix (`1_menu`) works too.
- **Properties:** only values that differ from the default are written. Leave a default out instead of writing it.
- **Sub-scene:** a node with `instance=ExtResource(...)` and no `type`. Its own nodes stay in its own file.
- **Unique names:** `unique_name_in_owner = true` on a node lets its scene's script write `%PlayButton`.

## uid and unique_id

Godot 4.7 writes `uid="uid://..."` in every header and `ext_resource`, and `unique_id=<number>` on every node it saves. Leave them out of what you write, and delete `unique_id=` from a node block you copy, so two nodes never share one. Keep the ones already in the file unchanged.

Once the files are written, `uv run tools/check.py ids` saves each one missing an id the way the editor does, so Godot assigns them. Commit what it saves with the change.

## References

Write an `ext_resource` with `path` alone, and let `uv run tools/check.py ids` add its `uid`, as it does for headers and nodes:

```
[ext_resource type="PackedScene" path="res://ui/settings/settings_menu.tscn" id="2_sett"]
```

Never type or copy a uid into one. The uid wins over the path: another file's uid loads that file instead, with no error, and an unknown one falls back to the path with only a warning. The load check, the smoke run and the tests all pass either way, so `check.py lint` fails on a uid that isn't its path's (rule `uid-matches-path`). Keep the uids already in the file unchanged.

## UI scenes

Build UI from Containers styled by the shared Theme in `ui/`:

- The root Control fills the screen with the full-rect block shown above (`layout_mode = 3`, `anchors_preset = 15`, anchors 1.0, grow 2) and carries `theme = ExtResource(...)`.
- A child of a Container gets `layout_mode = 2` and no anchors or offsets: the Container places it.
- Spacing comes from `MarginContainer` and the Theme's separations, never from per-node offsets.
- A variant of a control (a title label, a danger button) is a type variation in `ui/theme.tres`, which the node names with `theme_type_variation = &"TitleLabel"`. Add new variants to the Theme as `<Name>/base_type = &"Label"` plus their items, rather than as per-node overrides or a new scene ([Theme type variations](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_theme_type_variations.html)).

## Generating many nodes

For bulk generation (dozens of nodes, a grid of tiles), write a `-s` SceneTree script that builds the nodes, sets each one's `owner` to the root, and saves with `PackedScene.pack()` + `ResourceSaver.save()`. Run it with `--editor` (`godot --headless --editor --path . -s <script>`): outside editor mode the saver writes no uids, and `check.py ids` would then have to restore them. This rewrites every `id` and adds `unique_id`s, so the diff touches the whole file. Use text edits for everything smaller.

## Merge conflicts

Take one side whole: `git checkout --ours <file>` or `git checkout --theirs <file>`. Redo the other side's change by hand as a fresh edit, then run `uv run tools/check.py load`.
