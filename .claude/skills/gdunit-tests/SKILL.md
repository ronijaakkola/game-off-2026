---
name: gdunit-tests
description: Decide whether a change needs a test and which kind, then write, run and debug gdUnit4 tests in this project. Use when changing logic or a player-facing flow, fixing a bug, adding or changing tests under test/, testing a scene with simulated mouse or key input, awaiting a signal in a test, or reading a failing `check.py test` run.
---

# gdUnit4 tests

gdUnit4 6.2.2, vendored in `addons/gdUnit4/`. Run every test with `uv run tools/check.py test`.

## Which test, and when

**When.** A flow gets tests once it's settled: the human says so, or the ticket asks for them. Boilerplate work counts as settled. Until then the load check, the smoke run and the human's visual check cover it, and your handoff names each untested flow the change touched. A fixed bug is the exception: it gets a regression test right away, at whichever kind reproduces it.

**Which kind** (both defined in `CONTEXT.md`):

- A **scene test** is the default. Every player-facing flow gets one: drive the scene with clicks and keys, then assert what the player would see or hear, or a bus event. Copy `test/ui/main_menu/main_menu_test.gd`.
- A **unit test** calls public methods directly, in three cases: logic with many cases (a rule, a generator), a bug a scene test can't reach, and a core system, whose public calls are the unit. Copy `test/core/settings/settings_test.gd`.

**What a test checks.** Behaviour, through the public seam: the test goes red when the behaviour breaks, and only then. A test that would also go red on a harmless refactor is checking the implementation. Leave out tests of:

- setters, getters and `_`-prefixed methods
- wiring the engine or editor already guarantees, such as a signal connected in the `.tscn` or a node existing
- exact durations, colours, layout values and constants
- internals the player can't observe, such as pool size or which player plays a sound

Test against the real scene, or a fresh instance of a core system (see Core systems and user://). gdUnit's mocks and spies stay off our own scripts.

**Red first.** For logic, write the failing test, watch it go red, then make it pass. Pick the seam yourself (a scene's input, or a core system's calls) and name it in the handoff.

**Warning signs:** more than three scene tests for one flow (the variations belong in a unit test, or nowhere), a suite slower than about 30 s, or one test slower than about 2 s (shorten the duration under test). Going past one is fine when you say why in the handoff.

## Placement

A test mirrors the `res://` path of what it tests, named `<name>_test.gd`:

- `core/settings/settings.gd` → `test/core/settings/settings_test.gd`
- `ui/pause_menu/pause_menu.tscn` → `test/ui/pause_menu/pause_menu_test.gd`

## A suite

```gdscript
extends GdUnitTestSuite

const SCENE := "res://ui/pause_menu/pause_menu.tscn"


func test_open_pauses() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	assert_bool(runner.scene().get_tree().paused).is_true()
```

- Every function starting with `test_` is a test. Type everything: an untyped test fails to load.
- `before_test()` / `after_test()` run around each test, `before()` / `after()` once per suite.
- Pick the typed assert: `assert_int`, `assert_float`, `assert_bool`, `assert_str`, `assert_vector`, `assert_array`, `assert_object`, `assert_that`.
- Wrap objects you create with `auto_free(...)` so they're freed after the test. Scenes from `scene_runner` free themselves.

## Testing a scene

`scene_runner(path)` instantiates the scene in the tree and drives frames. Every scene must instantiate on its own, so any scene can be the target.

- `runner.scene()` is the root node. `runner.find_child("Name")` finds a node. `runner.get_property("name")`, `runner.set_property("name", value)` and `runner.invoke("method", args...)` reach into the root script.
- `await runner.simulate_frames(10)` advances frames.

**Mouse input** works headless. Point at a Control's centre and click:

```gdscript
var button := runner.find_child("PlayButton") as Button
await runner.simulate_frames(1)
runner.set_mouse_position(button.get_global_rect().get_center())
runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
await runner.await_input_processed()
```

- Wait one frame before reading a rect: Containers place their children a frame after entering the tree, so the button still sits at (0, 0) before that.
- Headless, the window is 64×64, and the `canvas_items` stretch scales every simulated click to match, so clicks miss. A suite that clicks sets the window to the base size in `before()` and restores it in `after()`. `test/ui/main_menu/main_menu_test.gd` shows both.

Keys and actions have their own calls, `simulate_key_pressed(KEY_ESCAPE)` and `simulate_action_pressed("pause")`, with one trap (below). Ignore the startup warning that input events aren't transported in headless mode; the cases above pass headless.

A click on the 3D view works headless when the scene casts its own ray from the click, as the example game scene does. Aim with `camera.unproject_position(world_point)`, send the click through `Input` alone (below), and wait for the result: the ray is cast in the next physics frame. `test/game/game_test.gd` shows it. Physics picking through `CollisionObject3D.input_event` is unverified.

The runner's key, action and mouse calls deliver each event twice to the scene root's `_unhandled_input`: once through the viewport and once by calling it directly. A root that toggles on a key (the pause menu on Esc) toggles back, and a root that acts on a click (the game placing a piece) acts twice. For those, send the event through `Input` alone, as `test/ui/pause_menu/pause_menu_test.gd` does:

```gdscript
var event := InputEventKey.new()
event.keycode = KEY_ESCAPE
event.pressed = true
Input.parse_input_event(event)
Input.flush_buffered_events()
```

## Signals

A signal emitted **during** the call you make (a click, an `invoke`) has already fired before any `await` starts. Start monitoring first, then assert:

```gdscript
monitor_signals(runner.scene())
runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
await assert_signal(runner.scene()).is_emitted("clicked", [1])
```

Bus events work the same way: `monitor_signals(Events)` then `await assert_signal(Events).is_emitted("piece_placed", [Vector3.ZERO])`.

A signal that fires **later** (after a timer or a tween) can be awaited directly: `await runner.await_signal("faded_in")`, or `await await_signal_on(node, "finished", [], 2000)` for any object. Both time out after 2 s by default and fail the test.

gdUnit's timeouts (`await_signal_on`, `wait_until`, the per-test timeout) are pausable Timers, so they stop while the tree is paused, and a stalled await hangs the whole run. While a test keeps the tree paused, await with `test/support/pause_proof_wait.gd`, whose deadline is wall-clock time, and return on failure before any gdUnit wait. `test/ui/pause_menu/pause_menu_test.gd` shows it:

```gdscript
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

var changed := await PauseProofWait.for_signal(get_tree().scene_changed, 2000)
assert_bool(changed).override_failure_message("SceneFlow never left the paused game").is_true()
if is_failure():
	return
```

## Core systems and user://

Autoloads (`Events`, `Audio`, `Settings`, `SceneFlow`) are live during tests and keep their state between tests. Reset what you change in `after_test()`.

To test a core system from a clean start, add a fresh instance of its script instead of using the live autoload: `add_child(auto_free(preload("res://core/settings/settings.gd").new()))` runs its `_ready()`. `user://settings.cfg` is the developer's own settings file, so never just delete it. `test/core/settings/settings_test.gd` shows the pattern: delete the file in `before_test()`, then in `after()` assign each live `Settings` value back to itself, which re-saves the file and restores the bus volumes.

## Tests that change scenes

When the editor's GdUnit panel runs the tests, gdUnit's runner scene is the tree's current scene. A test that changes scenes (`SceneFlow.go_to`, `change_scene_to_*`, the `goto` command) frees the runner, and the editor run then hangs with no error. Headless there is no current scene, so `check.py test` passes anyway. Every suite that changes scenes detaches the runner in `before()` and restores it in `after()`:

```gdscript
var _runner_scene: Node


func before() -> void:
	_runner_scene = get_tree().current_scene
	get_tree().current_scene = null


func after() -> void:
	get_tree().current_scene = _runner_scene
```

`after_test()` can then call `get_tree().unload_current_scene()` without touching the runner. `test/core/scene_flow/scene_flow_test.gd` shows the pattern.

`SceneFlow.go_to` disables the root's input until its fade back in ends, and ignores calls made before then. After a scene change, wait out the fade before the next click or scene change:

```gdscript
await await_signal_on(get_tree(), "scene_changed", [], 2000)
await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()
```

A test that fails or times out mid-transition leaves SceneFlow running. Its scene change then lands after `after_test()` unloads, and it ignores the next suite's `go_to` until it ends, so a later suite fails instead. So `after_test()` waits for the fade to end before it re-enables input and unloads. Unpause first: gdUnit's timeouts stall while the tree is paused. `test/ui/main_menu/main_menu_test.gd` and `test/ui/pause_menu/pause_menu_test.gd` show it:

```gdscript
func after_test() -> void:
	get_tree().paused = false
	await assert_func(get_tree().root, "is_input_disabled").wait_until(5000).is_false()
	get_tree().root.set_disable_input(false)
	get_tree().unload_current_scene()
```

Re-enable input only after the wait: input is SceneFlow's done flag, and setting it first makes the wait pass at once.

## Frame timing

`check.py test` runs headless, locally and in CI, so neither draws a frame and a frame takes a few milliseconds. A run that draws, such as the editor's gdUnit panel, can take far longer per frame: on llvmpipe, a software renderer, a frame of the game scene takes 40–70 ms. A test whose result depends on frame time, such as a tween's step per frame, turns drawing off with `RenderingServer.render_loop_enabled = false` and turns it back on in `after_test()`. `test_fades_in_smoothly_after_a_slow_first_frame` in `test/core/scene_flow/scene_flow_test.gd` shows it.

## Reading a failure

When tests fail, `check.py test` prints each failing test's block, then the summary:

```
  res://test/core/audio/audio_test.gd > test_same_track_keeps_playing FAILED 3ms
  Report:
  Expecting:
 5
 but was
 4	at 'test_same_track_keeps_playing' in res://test/core/audio/audio_test.gd:12

Overall Summary: 27 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans |
```

- A failure with no test block (a failing `before()` or `after()`) prints the full run instead.
- A run that finds no tests fails with `no test cases found in test/`.
- `await_signal_on(...) timed out` means the signal fired before the await, or never. See Signals.
- A test file that fails to parse aborts the whole run with exit code 105 and prints the parse error.
- Exit code 100 means failures. 101 means warnings only, which `check.py` counts as a pass.
- Reports are in `build/reports/report_N/` (HTML and JUnit XML).
