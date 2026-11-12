# Coding standards

How this project is organised. Godot 4.7.2, GDScript only. Words in **bold** are defined in `CONTEXT.md`.

`uv run tools/check.py lint` checks the rules here that need no Godot. Each message names its rule and the section behind it, so the section is where a rule's reason is.

Some topics have their own file, read when the work touches them: cameras in `docs/cameras.md`, models in the `blender-models` skill, scene and resource text in the `edit-tscn` skill, tests in the `gdunit-tests` skill.

## Layout

Folders are by feature:

| Folder | What goes there |
|---|---|
| `addons/` | Vendored plugins at pinned versions. Left exactly as vendored, except `addons/limbo_console.cfg`, which is the project's console config, and Phantom Camera, vendored without its `examples/` folder. |
| `core/<system>/` | One folder per autoload: `core/events/`, `core/audio/`, `core/scene_flow/`, `core/settings/`, `core/save_game/`, `core/feedback/`, `core/online/`, `core/dev_console/`, `core/debug_panel/`. |
| `ui/` | Main menu, settings panel, pause menu, the shared Theme, shared widgets. |
| `game/<feature>/` | The game, one folder per feature: `game/bus/`, `game/goals/`, `game/passengers/`, `game/research/`, `game/solar_system/`. |
| `shared/` | Assets used by more than one feature, such as `shared/two_tone.gdshader`. |
| `test/` | gdUnit4 tests, and preview scenes in `test/previews/` (Visual checks and previews). |
| `tools/` | `check.py`, `blender.py` and their helper scripts. Not exported. |
| `art/` | The **model library**, `art/models.blend`. Ignored by git and Godot. |
| `docs/` | Docs for people and agents, and their figures in `docs/figures/`. Ignored by Godot. |

A file lives in the folder of the only feature that uses it. Move it to `shared/` when a second feature needs it.

## Naming

Follow the [Godot GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html) verbatim:

- snake_case folders and files, PascalCase node names and `class_name`, snake_case functions and variables, CONSTANT_CASE constants, a leading `_` for private members.
- Signals are past tense: `docked`, `ran_out_of_fuel`.
- A scene and its script share a base name and sit side by side: `main_menu.tscn` + `main_menu.gd`.
- Add `class_name` only when another script refers to the type by name: a custom Resource, a component, an `is` check, a typed variable.
- A `##` comment documents the `func`, `signal` or member right under it, and the editor shows it there. When you put a function between a comment and the function it belongs to, the comment silently becomes the new function's doc. Each `[param name]` in a comment above a `func` or `signal` must be one of its parameters: `check.py lint` fails on one that isn't (`doc-param`).

`gdlint` enforces most of this, and `gdformat` sets the layout of every script. `uv run tools/check.py lint` runs both. `uv run tools/check.py format [files]` applies `gdformat`.

## Static typing

Every declaration is typed: variables, parameters, return types, loop variables. The `untyped_declaration` warning is an **Error** in `project.godot`, so an untyped script fails to load. It misses loop variables (`for i in 3:` loads), so `check.py lint` fails on those. Inferred types (`:=`) count as typed.

Reach another script's members through its type, not by name. `node.set(&"cabin", cabin)` loads, and once `cabin` is misspelled or renamed it sets nothing and `get()` returns null, with no error anywhere; a test that configures a scene that way then passes without testing what it says. Give the script a `class_name` (a typed variable is reason enough), cast to it and use the member: `(%PassengerPanel as PassengerPanel).cabin = cabin`. `check.py lint` fails on `set()` or `set_deferred()` with a literal name, and on `get()` with a `StringName` literal (`typed-member`). A name in a variable, as when binding controls by a setting's name, is fine.

An enum that an `@export` names, as a type or a default, numbers every member: `enum Type { BLUE = 0, ORANGE = 1, GREEN = 2 }`. A `.tres` or `.tscn` saves an exported enum as its number (`traits = Array[int]([6])`), and Godot counts unnumbered members from 0 in order, so a member added or moved above another renumbers it and every saved value loads as its neighbour, with no error anywhere. A new member takes the next unused number, wherever it sits. `check.py lint` fails on an unnumbered member of an exported enum (`saved-enum`), on the enum and on an export in another script.

Renaming or removing an `@export` leaves every value a `.tscn` or `.tres` saved under the old name behind: Godot skips a property the node or resource doesn't have, with no error, and it runs on the script's default. Rename the property in every file that stores it in the same change, as the glossary's terms make you do. `check.py load` fails on a scene or resource that stores a property its node, sub-resource or resource doesn't have (`stale-property`), naming the file, the node or sub-resource, and the script.

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
| `Settings` | `core/settings/` | The player's **settings**, applied on every change and saved to `user://settings.cfg` once changes stop for a moment. `reset()` puts them all back to their defaults. |
| `SaveGame` | `core/save_game/` | The player's **save game** in `user://save_game.json`, one run as a plain Dictionary. The main menu starts a run with `start_new()` or `continue_saved()`, and the game scene takes it with `claim_run()`; only a claimed run is written, so tests and F6 runs never touch the save. Tests run in the player's own user folder, so a test that starts a run from the menu points `SaveGame.path` at a file of its own first. It knows nothing of the game: `GameSaver` in the solar system builds and applies the Dictionary. |
| `Feedback` | `core/feedback/` | Game feel effects: `Feedback.shake(amount, direction)`. It owns the camera's `h_offset`/`v_offset`, so game cameras keep them at 0, and with Phantom Camera they stay out of `Camera3DResource`. |
| `Talo` | `addons/talo/` | The Talo plugin's autoload. Only `core/online/` names it; see Online. |
| `Online` | `core/online/` | The online services through Talo: `track(event, props)`, `add_stat(stat)`, `submit_score(board, score)`, `get_scores(board)`, `flush()`. On only in web builds with an access key. `core/online/tracking.gd` turns bus events into analytics. |
| `LimboConsole` | `addons/limbo_console/` | The dev console (plugin). Editor and desktop only; see Dev console. |
| `DevConsole` | `core/dev_console/` | Loads `dev_commands.gd` when `LimboConsole` is running. See Dev console. |
| `DebugPanel` | `core/debug_panel/` | The **debug panel**: testing buttons that scenes add with `add_button(text, action, scene)`, opened with F2. In every build until release. See Debug panel. |
| `PhantomCameraManager` | `addons/phantom_camera/` | The Phantom Camera plugin's autoload. Game code never calls it; see `docs/cameras.md`. |

Add an autoload only for a service that must outlive a scene change, or that has exactly one instance game-wide. It lives in `core/<name>/`, works without knowing what the current scene is, and gets a row in this table.

## Scene composition

Call down, signal up.

- A parent calls methods on its children. A child tells its parent things by emitting a local signal.
- A scene reaches its own nodes through unique names: mark the node `unique_name_in_owner` and write `%Button`.
- Dependencies from outside the scene come in through `@export` vars or a setter the parent calls.
- Scenes stay unaware of their surroundings: no `get_parent()`, no `../` paths, no `/root/...` paths.
- Every scene instantiates on its own without errors, so it runs with F6 in the editor, `uv run tools/check.py smoke <scene>`, and a gdUnit4 `scene_runner`. `smoke` with no scenes runs every scene the game reaches: the main scene, and every scene a reached scene instances or a reached script names by path, such as a `SceneFlow.go_to` target. A sub-scene that errors outside its parent fails it; a scene nothing references yet is left out until something does, and so is every scene in `tools/` and `test/`. A path that names no file would drop its scene, and every scene only it leads to, so `check.py lint` fails on one in a game script (`path-exists`); a string with `%` or `{` is a template and is left alone. `export` boots the same scenes from the exported pack, which leaves out `test/`, `tools/`, the dev console and any file that isn't a resource.

## Script size

A script is at most 600 lines; `gdlint` fails a longer one (`max-file-lines`). Past that, a script usually does more than one job. GDScript has no partial classes, so split it by job, not by line count:

- **A component node.** Behaviour with its own state and lifecycle, such as health, a cooldown or an input buffer, moves to a child node with its own script and `class_name`. The parent calls down to it, and it signals up (Scene composition).
- **A static helper.** Pure logic that reads no node, such as scoring rules or grid maths, moves to a `class_name` script of `static func`s next to the script that uses it. It tests without a scene.
- **A Resource.** Tuning values and data tables move to a custom `Resource` with `@export` vars, saved as a `.tres` and set on the scene through an `@export`.

Each new file follows Layout and Naming. Never split into numbered parts or a `*_helpers.gd` grab-bag: each new script is named after the one job it does.

From 500 lines, `check.py lint` warns (`script-size`). A change that adds to such a script moves one job out in the same change, so the script ends no longer than it started. Trimming comments, joining lines or dropping blank lines to fit is not a split: the script still does as many jobs, and the next change meets the same wall. When no job comes out cleanly, say so in the handoff and name the split you would make, so the human can decide.

## Signals: local or bus

Use a local signal by default.

Put a signal on `Events` only for a **bus event**: a broadcast fact that parts of the game which don't know each other react to. Bus events are:

- past tense, with typed parameters,
- documented with a `##` comment,
- declared in `core/events/events.gd`, and added only when something listens.

```gdscript
## A passenger got off at their destination with [param rating] stars.
signal passenger_delivered(rating: int)
```

A **command** to a core system is a direct autoload call: `SceneFlow.go_to(...)`, `Audio.play_sfx(...)`. Commands are never bus signals, so a `*_requested` signal is a sign that you need a direct call instead.

Core systems emit on `Events` and declare no public signals of their own. Consumers read a setting from `Settings` when they use it.

## UI

Build UI from Containers (`VBoxContainer`, `MarginContainer`, `CenterContainer`, …) styled by the shared Theme in `ui/`. Containers keep text edits to `.tscn` predictable and scale with the `canvas_items` stretch mode. Set anchors only on the root Control of a scene.

- A Control that covers the 3D view, such as a HUD's root and its full-size Containers, sets `mouse_filter` to `IGNORE` (`mouse_filter = 2` in a `.tscn`). It is the only filter the docs say "will not block other controls" from getting the click; `PASS` takes the click and bubbles it up to the parent ([MouseFilter](https://docs.godotengine.org/en/4.7/classes/class_control.html#enum-control-mousefilter)).
- A Control shows game state; it never holds the only copy. The player's credits, research points and ratings live in `Ledger` (`SolarSystem.get_ledger()`), and the resource bar's counters only show it, animating each change it signals. Game code reads and changes the ledger, never a counter. A new readout follows suit: its value in a plain object or node the game owns, and the Control given that owner.
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
- The solar system picks planets and the bus without physics: it compares the pointer with each one's `Camera3D.unproject_position()` on screen. Do the same for anything round and few.
- When something does need a ray, cast it with `Camera3D.project_ray_origin()` and `project_ray_normal()` into `PhysicsDirectSpaceState3D.intersect_ray()`, from `_physics_process()`. The space may be locked during `_input()` ([Ray-casting](https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html)), so keep the click's position and cast in the next physics frame. For a one-off "does it fit here?" check, use `intersect_shape()` instead of an `Area3D`.
- Under Jolt, the Debugger's physics monitors (active objects, collision pairs, islands) always read 0. Don't use them to debug.

## Editing `.tscn` and `.tres`

Agents may hand-edit any `.tscn` or `.tres` as text, visual properties included. The `edit-tscn` skill has the file shape and the rules for `uid://` references, `unique_id` and `node_paths`.

- Run `uv run tools/check.py load` after every edit.
- Never invent or copy a `uid` or a `unique_id`. Leave them out of what you write, then run `uv run tools/check.py ids` and commit what it saves with the change. Godot assigns them on save, so they are committed once: two people saving the same file before that get different numbers, and every line conflicts.
- `ids` saves each file through Godot's editor-mode saver. If the save changed any stored value as the game loads it, it puts the files back and fails, naming each value.

## Plugins

- Vendored plugins live in `addons/` at pinned versions (README.md, Pinned versions) and stay exactly as vendored.
- Each plugin folder has a deny rule in `.claude/settings.json`, such as `Edit(/addons/talo/**)`, so agents can read it but not edit it. Vendoring a new plugin adds its rule in the same change.
- Enabling a plugin from a script misses the settings the editor writes. An agent vendors the files, then its handoff asks the human to enable `<plugin>` in Project Settings › Plugins and commit the `project.godot` diff.
- Upgrading a plugin is the human's job.

## Visual checks and previews

After a visual change, capture the scene (`uv run tools/check.py capture <scene>`) and look at the frame. Tuning by eye in the editor is recommended, never required. What the handoff says about a change of feel is in `CLAUDE.md`, Handoff.

A **preview** is a scene in `test/previews/<scene>_preview.tscn` that sets up made-up state and instances the real scene, for a scene that shows its look only with that state, such as the passenger cards with a full cabin.

- Add one only when a scene needs it to be looked at. Anything a test can set up and assert by itself, it does in the test: a test runs headless and can't make a frame, and that is the only thing a preview is for.
- Keep it to setup, so the frame shows the real scene.
- A preview that can show several states (another planet, a later moment) reads which from `OS.get_cmdline_user_args()`, so `capture <preview> -- <args>` picks one without a copy of the preview.
- Until the scene is settled (the `gdunit-tests` skill), `smoke <preview>` covers it. Once it is, give it one scene test in the real scene's suite that runs the preview and asserts the state it shows, so a preview that breaks fails `test`.

## Saved files

A file in `user://` belongs to one script, which writes its path once, as a `const`: `Settings.PATH`, `Online.PLAYER_PATH`. Everything else, tests included, names that const (`preload("res://core/settings/settings.gd").PATH` in a test). No check sees `user://`, so a copy left behind when the path changes reads or deletes a file nothing writes, and a test of it passes without testing anything. `check.py lint` fails on a second script that writes the same path (`user-path-owner`).

## Tests

- `test/` mirrors the `res://` path of what it tests, and files are named `<name>_test.gd`: `core/audio/audio.gd` → `test/core/audio/audio_test.gd`.
- The Web export drops `test/`.
- A test that logs an error or warning fails, naming the line that logged it, as `smoke` does (`report/godot/push_error` in `project.godot`). A test that checks for an error uses `assert_error(callable).is_push_error(message)`.
- A test may load any project file. When the file moves, the test fails naming it, and the fix is to update the path.
- The `gdunit-tests` skill has the gdUnit4 patterns.

## Assets

- No Git LFS. Question or compress any single asset over about 10 MB.
- Commit every `*.uid` and `*.import` file Godot creates next to your files, and delete a `.uid` with its file (`lint` fails on one left behind).
- Name a scratch file, such as a probe script or a throwaway scene, `tmp_*`, or put it in a `tmp/` folder. Git ignores both, so it can't reach a commit.
- To change how an asset imports, edit the value under `[params]` in its `.import` file, then run `uv run tools/check.py load`, which reimports it. Write the edit at least a second after the last import: Godot notices it by the file's modification time.

## Models

Models are made in Blender 5.2, in the **model library** (`art/models.blend`), and committed only as exported `.glb` files: `<feature>/models/<model>.glb` with its `.glb.import`, plus any extracted `<model>_<image>.png` and `.png.import`. A model used by a second feature moves to `shared/models/`.

Blender is needed only by whoever makes models; CI and `check.py` see only the `.glb` files, and `check.py load` loads every one. The `blender-models` skill has the conventions every model follows and the Blender side.

## Merges

Godot scenes merge badly, so prevent conflicts:

- Keep scenes small and composed. One person (and their agent) works on a scene at a time; claim it in team chat.
- Pull or rebase with the editor closed, or at least the affected scenes. The editor overwrites pulled changes when it saves its in-memory copy.
- A conflicted `.tscn` or `.tres` is never merged by hand: take one side whole and redo the other change (the `edit-tscn` skill, Merge conflicts).
- `project.godot` is INI and can be hand-merged.

## Dev console

`LimboConsole` is left out of the web build, so any script that names it fails to compile there. All console code lives in `core/dev_console/dev_commands.gd`, which is also left out of the web build. The `DevConsole` autoload loads it only when `get_tree().root.get_node_or_null(^"LimboConsole")` exists. Add new console commands there; open the console with F1 in an editor run. F1 is the same key on every keyboard layout; a backtick toggle can't be typed on Nordic layouts.

The web build logs one `Failed to instantiate an autoload` error at startup, for the missing `LimboConsole`. That line is expected.

## Debug panel

`DebugPanel` (`core/debug_panel/`) is a side panel of testing buttons, opened and closed with F2, for anything quicker to test with a click than a console command. It works while paused, and starts closed.

- A scene adds its buttons in `_ready()`: `DebugPanel.add_button("Empty fuel", _debug_empty_fuel, self)`. Each button goes when the scene that added it leaves the tree, so the panel never knows which scene runs. Name the scene's handler `_debug_<what it does>`, next to the scene's other handlers.
- Related buttons that would crowd the main card, such as the bus's stat buttons, go in a group: `DebugPanel.add_button("+1 seat", action, self, "Stats")`. Each group gets its own card to the right of the main one, opened and closed by a button of the group's name in the main card, one group's card at a time. The card and its button go with the group's last button.
- Unlike the dev console, it ships in every build, web and release builds included, so testers can use it on itch.io. Release builds are made before the game is out, so being a release build doesn't turn it off.
- **Before the game is released**, set `ENABLED` to `false` in `core/debug_panel/debug_panel.gd`. F2 then does nothing, and `add_button` adds nothing, so the scenes' calls can stay.

## Online

Game code reaches Talo only through `Online`, which is on only in web builds with an access key, and batches what it sends. A direct `Talo` call skips both, and errors when no player is identified. So only `core/online/` names the `Talo` autoload; tests, `tools/` and `dev_commands.gd` may too. Talo's classes, such as `TaloLeaderboardEntry`, are fine as types anywhere. When a game needs a Talo feature `Online` doesn't wrap, add a method to `core/online/online.gd`. `docs/online.md` has the setup and the wiring.
