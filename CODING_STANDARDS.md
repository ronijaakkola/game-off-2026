# Coding standards

How this project is organised. Godot 4.7.2, GDScript only. Words in **bold** are defined in `CONTEXT.md`.

`uv run tools/check.py lint` checks the rules here that need no Godot: naming and layout, typed loop variables, the node paths in Scene composition, bus events and core system signals, where `LimboConsole`, `Talo` and audio bus names are named, test file names, two nodes sharing a `unique_id`, a scene or resource missing its ids or naming a uid that isn't its path's, and asset size (a warning only). Each message names its rule and section.

## Layout

Folders are by feature:

| Folder | What goes there |
|---|---|
| `addons/` | Vendored plugins at pinned versions. Left exactly as vendored, except `addons/limbo_console.cfg`, which is the project's console config. |
| `core/<system>/` | One folder per autoload: `core/events/`, `core/audio/`, `core/scene_flow/`, `core/settings/`, `core/feedback/`, `core/online/`, `core/dev_console/`. |
| `ui/` | Main menu, settings panel, pause menu, the shared Theme, shared widgets. |
| `game/` | The **example game scene**, replaced on jam day. |
| `shared/` | Assets used by more than one feature, such as `shared/audio/`. |
| `test/` | gdUnit4 tests. |
| `tools/` | `check.py`, `blender.py` and their helper scripts. Not exported. |
| `art/` | The **model library**, `art/models.blend`. Ignored by git and Godot. |

A file lives in the folder of the only feature that uses it. Move it to `shared/` when a second feature needs it.

## Naming

Follow the [Godot GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html) verbatim:

- snake_case folders and files, PascalCase node names and `class_name`, snake_case functions and variables, CONSTANT_CASE constants, a leading `_` for private members.
- Signals are past tense: `piece_placed`, `level_completed`.
- A scene and its script share a base name and sit side by side: `main_menu.tscn` + `main_menu.gd`.
- Add `class_name` only when another script refers to the type by name: a custom Resource, a component, an `is` check, a typed variable.

`gdlint` enforces most of this, and `gdformat` sets the layout of every script. `uv run tools/check.py lint` runs both. `uv run tools/check.py format [files]` applies `gdformat`.

## Static typing

Every declaration is typed: variables, parameters, return types, loop variables. The `untyped_declaration` warning is an **Error** in `project.godot`, so an untyped script fails to load. It misses loop variables (`for i in 3:` loads), so `check.py lint` fails on those. Inferred types (`:=`) count as typed.

```gdscript
var speed := 4.0
var target: Node3D
func place(at: Vector3) -> void:
for piece: Node3D in pieces:
```

## Checking an API

APIs change between Godot versions. Before writing code against a class, method, property, signal or annotation you aren't sure exists in 4.7.2, look it up in the engine's own class reference:

- `uv run tools/check.py api Tween`: the class, its parents, and its own members, one line each.
- `uv run tools/check.py api Tween.kill`: one member in full, with its description. Inherited members work too.
- `uv run tools/check.py api volume_linear`: a search, when you don't know the class. It also finds `@GlobalScope` functions such as `lerpf` and `@GDScript` annotations such as `@export_range`.

The first run builds the reference into `build/api/` in a few seconds. A name that doesn't exist fails with close matches.

## Autoloads (core systems)

| Autoload | Folder | What it does |
|---|---|---|
| `Events` | `core/events/` | The **signal bus**: every **bus event**, declared in `events.gd`. |
| `Audio` | `core/audio/` | Music crossfade and pooled SFX: `play_music(stream)`, `stop_music()`, `play_sfx(stream)`. It owns the buses: code names one as an `Audio.Bus`, so `set_volume(Audio.Bus.MUSIC, linear)`, and a player's bus is `Audio.BUS_NAMES[Audio.Bus.SFX]`. A wrong bus name plays on Master without an error. |
| `SceneFlow` | `core/scene_flow/` | Moves between top-level scenes with a fade: `await SceneFlow.go_to(path)`. |
| `Settings` | `core/settings/` | The player's **settings**, applied on every change and saved to `user://settings.cfg` once changes stop for a moment. |
| `Feedback` | `core/feedback/` | Game feel effects: `Feedback.shake(amount, direction)`. It owns the camera's `h_offset`/`v_offset`, so game cameras keep them at 0, and with Phantom Camera they stay out of `Camera3DResource`. |
| `Talo` | `addons/talo/` | The Talo plugin's autoload. Only `core/online/` names it; see Online. |
| `Online` | `core/online/` | The online services through Talo: `track(event, props)`, `add_stat(stat)`, `submit_score(board, score)`, `get_scores(board)`, `flush()`. On only in web builds with an access key. `core/online/tracking.gd` turns bus events into analytics. |
| `LimboConsole` | `addons/limbo_console/` | The dev console (plugin). Editor and desktop only; see Dev console. |
| `DevConsole` | `core/dev_console/` | Loads `dev_commands.gd` when `LimboConsole` is running. See Dev console. |

Add an autoload only for a service that must outlive a scene change, or that has exactly one instance game-wide. It lives in `core/<name>/`, works without knowing what the current scene is, and gets a row in this table.

## Scene composition

Call down, signal up.

- A parent calls methods on its children. A child tells its parent things by emitting a local signal.
- A scene reaches its own nodes through unique names: mark the node `unique_name_in_owner` and write `%Button`.
- Dependencies from outside the scene come in through `@export` vars or a setter the parent calls.
- Scenes stay unaware of their surroundings: no `get_parent()`, no `../` paths, no `/root/...` paths.
- Every scene instantiates on its own without errors, so it runs with F6 in the editor, `uv run tools/check.py smoke <scene>`, and a gdUnit4 `scene_runner`.

## Script size

A script is at most 600 lines; `gdlint` fails a longer one (`max-file-lines`). Past that, a script usually does more than one job. GDScript has no partial classes, so split it by job, not by line count:

- **A component node.** Behaviour with its own state and lifecycle, such as health, a cooldown or an input buffer, moves to a child node with its own script and `class_name`. The parent calls down to it, and it signals up (Scene composition).
- **A static helper.** Pure logic that reads no node, such as scoring rules or grid maths, moves to a `class_name` script of `static func`s next to the script that uses it. It tests without a scene.
- **A Resource.** Tuning values and data tables move to a custom `Resource` with `@export` vars, saved as a `.tres` and set on the scene through an `@export`.

Each new file follows Layout and Naming. Never split into numbered parts or a `*_helpers.gd` grab-bag: each new script is named after the one job it does.

## Signals: local or bus

Use a local signal by default.

Put a signal on `Events` only for a **bus event**: a broadcast fact that parts of the game which don't know each other react to. Bus events are:

- past tense, with typed parameters,
- documented with a `##` comment,
- declared in `core/events/events.gd`, and added only when something listens.

```gdscript
## A piece was placed on the board at [param position] (world space).
signal piece_placed(position: Vector3)
```

A **command** to a core system is a direct autoload call: `SceneFlow.go_to(...)`, `Audio.play_sfx(...)`. Commands are never bus signals, so a `*_requested` signal is a sign that you need a direct call instead.

Core systems emit on `Events` and declare no public signals of their own. Consumers read a setting from `Settings` when they use it.

## UI

Build UI from Containers (`VBoxContainer`, `MarginContainer`, `CenterContainer`, …) styled by the shared Theme in `ui/`. Containers keep text edits to `.tscn` predictable and scale with the `canvas_items` stretch mode. Set anchors only on the root Control of a scene.

- A Control that covers the 3D view, such as a HUD's root and its full-size Containers, sets `mouse_filter` to `IGNORE` (`mouse_filter = 2` in a `.tscn`). It is the only filter the docs say "will not block other controls" from getting the click; `PASS` takes the click and bubbles it up to the parent ([MouseFilter](https://docs.godotengine.org/en/4.7/classes/class_control.html#enum-control-mousefilter)).
- To change a Theme StyleBox at runtime, `duplicate()` it and apply the copy with `add_theme_stylebox_override()`. The StyleBox is shared, so editing it in place changes every control that uses it ([add_theme_stylebox_override](https://docs.godotengine.org/en/4.7/classes/class_control.html#class-control-method-add-theme-stylebox-override)).

## Tweens

Keep one `Tween` per animated property in a variable, and `kill()` it before creating the next. Two tweens on one property fight, and a finished tween can't be reused ([Tween](https://docs.godotengine.org/en/4.7/classes/class_tween.html#description)).

```gdscript
var _fade: Tween

func fade_in() -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.2)
```

- `create_tween()` already binds the tween to the node ([Node.create_tween](https://docs.godotengine.org/en/4.7/classes/class_node.html#class-node-method-create-tween)). `bind_node()` is only for `get_tree().create_tween()`.
- A bound tween runs whenever its node can process ([TweenPauseMode](https://docs.godotengine.org/en/4.7/classes/class_tween.html#enum-tween-tweenpausemode)). The game pauses with `get_tree().paused`, so motion that plays while paused belongs to a node with `process_mode = PROCESS_MODE_ALWAYS`, like the pause menu and `SceneFlow`.
- Start a tween from the event that begins the motion: a signal, an input, a setter. When it must start from `_process`, guard it so it starts once, not every frame.

## Physics

- The project runs Jolt Physics (`physics/3d/physics_engine` in `project.godot`). It works in the single-threaded web build.
- Pick with the mouse by casting a ray: `Camera3D.project_ray_origin()` and `project_ray_normal()` into `PhysicsDirectSpaceState3D.intersect_ray()`. For a one-off "does it fit here?" check, use `intersect_shape()` instead of an `Area3D`.
- Cast from `_physics_process()`. The space may be locked during `_input()` ([Ray-casting](https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html)), so keep the click's position and cast in the next physics frame. `game/game.gd` shows it.
- Under Jolt, the Debugger's physics monitors (active objects, collision pairs, islands) always read 0. Don't use them to debug.

## Editing `.tscn` and `.tres`

Agents may hand-edit any `.tscn` or `.tres` as text, visual properties included. Use the `edit-tscn` skill, which covers `uid://` references and `unique_id`, and run `uv run tools/check.py load` after every edit.

A scene or resource written as text has no `uid` in its header or its `ext_resource`s and no `unique_id` on its new nodes, and agents don't invent or copy them. Godot's save assigns random ones, so they're committed once, by whoever saves first: two people saving the same file before that commit get different numbers, and every line conflicts. After writing a `.tscn` or `.tres`, run `uv run tools/check.py ids` and commit what it saves with the change. It saves each file missing an id through Godot's editor-mode saver, sub-scenes and resources before the scenes that use them, so every reference picks up its uid. Lint fails on a file still missing one, and on an `ext_resource` whose uid isn't its path's: Godot loads by uid, so a wrong one loads another file without an error.

Plugins have the same gap: enabling one from a script misses the settings the editor writes. An agent vendors the plugin's files into `addons/` at a pinned version, then its handoff asks the human to enable `<plugin>` in Project Settings › Plugins and commit the `project.godot` diff.

Each vendored plugin folder has a deny rule in `.claude/settings.json`, such as `Edit(/addons/talo/**)`, so agents can read it but not edit it. Vendoring a new plugin adds its rule in the same change. Upgrading a plugin is the human's job.

After a visual change, capture the scene (`uv run tools/check.py capture <scene>`) and look at the frame. When the change is about feel (the soft look, lighting, camera, motion), end the handoff with "Needs a visual check: `<scene>`". Tuning by eye in the editor is recommended, never required.

## Tests

- `test/` mirrors the `res://` path of what it tests, and files are named `<name>_test.gd`: `core/audio/audio.gd` → `test/core/audio/audio_test.gd`.
- The Web export drops `test/`.
- A test may load any project file, the example game's scene and sounds included. When the file moves, the test fails naming it, and the fix is to update the path.
- The `gdunit-tests` skill has the gdUnit4 patterns.

## Assets

- No Git LFS. Question or compress any single asset over about 10 MB.
- Commit every `*.uid` and `*.import` file Godot creates next to your files.
- To change how an asset imports, edit the value under `[params]` in its `.import` file, then run `uv run tools/check.py load`, which reimports it. Write the edit at least a second after the last import: Godot notices it by the file's modification time.

## Models

Models are made in Blender 5.2, in the **model library** (`art/models.blend`, one collection per model), and committed only as exported `.glb` files: `<feature>/models/<model>.glb` with its `.glb.import`, plus any extracted `<model>_<image>.png` and `.png.import`. A model used by a second feature moves to `shared/models/`. Blender is needed only by whoever makes models; CI and `check.py` see only the `.glb` files, and `check.py load` loads every one. The `blender-models` skill and `uv run tools/blender.py` do the Blender side.

Every model follows these conventions:

- 1 Blender unit = 1 m, transforms applied, origin at the bottom centre (it sits on the ground at y = 0), front facing Blender −Y (Godot's +Z).
- PascalCase object and material names. Objects become node names.
- Colour from flat Principled materials, about 4 per model at most: each is a draw call per mesh, and Compatibility has no automatic instancing. No vertex colours: they show darker than in Blender. An image texture, when one is needed, is 1024 px at most.
- Collision as a separate simple mesh named `<Name>-colonly`, which Godot imports as a `StaticBody3D`. No other name hints; other import settings go in the `.glb.import`.
- Godot's default import settings.

## Merges

Godot scenes merge badly, so prevent conflicts:

- Keep scenes small and composed. One person (and their agent) works on a scene at a time; claim it in team chat.
- Pull or rebase with the editor closed, or at least the affected scenes. The editor overwrites pulled changes when it saves its in-memory copy.
- A conflicted `.tscn` or `.tres`: take one side whole (`git checkout --ours <file>` or `--theirs`), redo the other change by hand, then run `uv run tools/check.py load`.
- `project.godot` is INI and can be hand-merged.

## Dev console

`LimboConsole` is left out of the web build, so any script that names it fails to compile there. All console code lives in `core/dev_console/dev_commands.gd`, which is also left out of the web build. The `DevConsole` autoload loads it only when `get_tree().root.get_node_or_null(^"LimboConsole")` exists. Add new console commands there; open the console with F1 in an editor run. F1 is the same key on every keyboard layout; a backtick toggle can't be typed on Nordic layouts.

The web build logs one `Failed to instantiate an autoload` error at startup, for the missing `LimboConsole`. That line is expected.

## Online

Game code reaches Talo only through `Online`, which is on only in web builds with an access key, and batches what it sends. A direct `Talo` call skips both, and errors when no player is identified. So only `core/online/` names the `Talo` autoload; tests, `tools/` and `dev_commands.gd` may too. Talo's classes, such as `TaloLeaderboardEntry`, are fine as types anywhere. When a game needs a Talo feature `Online` doesn't wrap, add a method to `core/online/online.gd`. `docs/online.md` has the setup and the wiring.
