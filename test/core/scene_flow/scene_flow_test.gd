extends GdUnitTestSuite

const SceneFlowScript := preload("res://core/scene_flow/scene_flow.gd")
const SOLAR_SYSTEM := "res://game/solar_system/solar_system.tscn"
const LEVEL_1 := "res://shared/level_art/level_1.tres"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")
## How long the simulated slow frame takes.
const SLOW_FRAME_SECONDS := 0.4

var _flow: SceneFlowScript
var _runner_scene: Node
# The overlay's alpha at the start of each process step: what the frame before it showed.
var _shown_alphas: Array[float] = []


func before() -> void:
	# In the editor, gdUnit's runner is the current scene, and changing scenes would free
	# it mid-run. Headless, there is no current scene.
	_runner_scene = get_tree().current_scene
	get_tree().current_scene = null


func after() -> void:
	get_tree().current_scene = _runner_scene


func before_test() -> void:
	_flow = auto_free(SceneFlowScript.new())
	add_child(_flow)


func after_test() -> void:
	if get_tree().process_frame.is_connected(_record_shown_alpha):
		get_tree().process_frame.disconnect(_record_shown_alpha)
	if get_tree().process_frame.is_connected(_end_slow_frame):
		get_tree().process_frame.disconnect(_end_slow_frame)
	_shown_alphas.clear()
	Engine.time_scale = 1.0
	RenderingServer.render_loop_enabled = true
	# A failed transition must not leave input off for the rest of the suite.
	get_tree().root.set_disable_input(false)
	get_tree().paused = false
	get_tree().unload_current_scene()


func test_changes_the_current_scene_and_hides_the_loading_card() -> void:
	await _flow.go_to(SOLAR_SYSTEM)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(SOLAR_SYSTEM)
	assert_bool(_curtain().visible).is_false()


func test_a_level_waits_paused_under_its_loading_screen_until_start() -> void:
	_flow.go_to(SOLAR_SYSTEM, load(LEVEL_1))
	var start := _flow.find_child("StartButton", true, false) as Button
	var shown := await PauseProofWait.for_condition(start.is_visible_in_tree, 5000)
	assert_bool(shown).override_failure_message("Start never showed").is_true()
	if is_failure():
		return
	assert_str(get_tree().current_scene.scene_file_path).is_equal(SOLAR_SYSTEM)
	assert_bool(get_tree().paused).is_true()
	assert_bool(_flow.is_busy()).is_true()

	start.pressed.emit()
	assert_bool(get_tree().paused).is_false()
	await assert_func(_flow, "is_busy").wait_until(2000).is_false()
	assert_bool(_curtain().visible).is_false()


func test_a_jump_into_a_level_waits_paused_under_its_loading_screen_until_start() -> void:
	var done := [false]
	var show := func() -> void:
		await _flow.show_loading_screen(load(LEVEL_1))
		done[0] = true
	show.call()
	var start := _flow.find_child("StartButton", true, false) as Button
	var shown := await PauseProofWait.for_condition(start.is_visible_in_tree, 5000)
	assert_bool(shown).override_failure_message("No Start").is_true()
	var paused := await PauseProofWait.for_condition(func() -> bool: return get_tree().paused, 5000)
	assert_bool(paused).override_failure_message("The game never paused").is_true()
	if is_failure():
		return
	assert_bool(_flow.is_busy()).is_true()
	assert_bool(done[0]).is_false()

	start.pressed.emit()
	assert_bool(get_tree().paused).is_false()
	await assert_func(_flow, "is_busy").wait_until(2000).is_false()
	assert_bool(done[0]).is_true()
	assert_bool(_curtain().visible).is_false()


# With nothing left to load, Start showed at once and the screen never read as loading.
func test_a_level_fills_its_bar_for_a_while_before_start_shows() -> void:
	_flow.go_to(SOLAR_SYSTEM, load(LEVEL_1))
	var start := _flow.find_child("StartButton", true, false) as Button
	var marker_way := _flow.find_child("Loaded", true, false) as Control
	var shares: Array[float] = []
	var record := func() -> void:
		if not start.is_visible_in_tree():
			shares.append(marker_way.size_flags_stretch_ratio)
	get_tree().process_frame.connect(record)
	var shown := await PauseProofWait.for_condition(start.is_visible_in_tree, 10000)
	get_tree().process_frame.disconnect(record)
	assert_bool(shown).override_failure_message("Start never showed").is_true()
	if is_failure():
		return
	assert_float(shares.size() * get_process_delta_time()).is_greater(_flow.min_loading_seconds)
	var sorted := shares.duplicate()
	sorted.sort()
	assert_array(shares).override_failure_message("The marker went back").is_equal(sorted)
	assert_float(shares.back()).is_greater(0.9)
	start.pressed.emit()
	await assert_func(_flow, "is_busy").wait_until(2000).is_false()


func test_a_jump_fills_its_bar_paused_for_a_while_before_start_shows() -> void:
	_flow.show_loading_screen(load(LEVEL_1))
	var start := _flow.find_child("StartButton", true, false) as Button
	var frames := [0]
	var count := func() -> void:
		if not start.is_visible_in_tree():
			frames[0] += 1
	get_tree().process_frame.connect(count)
	var paused := await PauseProofWait.for_condition(func() -> bool: return get_tree().paused, 5000)
	assert_bool(paused).override_failure_message("The game never paused").is_true()
	assert_bool(start.is_visible_in_tree()).override_failure_message("Start too soon").is_false()
	var shown := await PauseProofWait.for_condition(start.is_visible_in_tree, 10000)
	get_tree().process_frame.disconnect(count)
	assert_bool(shown).override_failure_message("Start never showed").is_true()
	if is_failure():
		return
	assert_float(frames[0] * get_process_delta_time()).is_greater(_flow.min_loading_seconds)
	start.pressed.emit()
	await assert_func(_flow, "is_busy").wait_until(2000).is_false()


func test_a_jump_into_a_level_without_a_picture_shows_nothing() -> void:
	await _flow.show_loading_screen(Level.new())
	assert_bool(_curtain().visible).is_false()
	assert_bool(_flow.is_busy()).is_false()
	assert_bool(get_tree().paused).is_false()


# The curtain's fade reaches each of its children apart, so "Loading…" under the level's
# loading screen showed through the picture as it faded.
func test_the_plain_loading_card_shows_only_for_a_level_without_a_picture() -> void:
	_flow.go_to(SOLAR_SYSTEM, load(LEVEL_1))
	assert_bool(_flow._plain.visible).override_failure_message("Under the picture").is_false()
	var start := _flow.find_child("StartButton", true, false) as Button
	assert_bool(await PauseProofWait.for_condition(start.is_visible_in_tree, 5000)).is_true()
	start.pressed.emit()
	await assert_func(_flow, "is_busy").wait_until(2000).is_false()

	_flow.go_to(SOLAR_SYSTEM)
	assert_bool(_flow._plain.visible).override_failure_message("Not entering a level").is_false()
	await assert_func(_flow, "is_busy").wait_until(5000).is_false()

	_flow.go_to(SOLAR_SYSTEM, Level.new())
	assert_bool(_flow._plain.visible).is_true()


func test_blocks_input_only_while_fading() -> void:
	_flow.go_to(SOLAR_SYSTEM)
	assert_bool(get_tree().root.is_input_disabled()).is_true()
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


func test_ignores_a_call_during_a_transition() -> void:
	_flow.go_to(SOLAR_SYSTEM)
	await _flow.go_to("res://does_not_exist.tscn")
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(SOLAR_SYSTEM)


func test_the_next_scene_starts_unpaused() -> void:
	get_tree().paused = true
	_flow.go_to(SOLAR_SYSTEM)
	var changed := await PauseProofWait.for_signal(get_tree().scene_changed, 2000)
	assert_bool(changed).override_failure_message("SceneFlow never left the paused scene").is_true()
	if is_failure():
		return
	assert_bool(get_tree().paused).is_false()
	if is_failure():
		return
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


func test_loads_only_after_a_black_frame_is_shown() -> void:
	# On the web, load() freezes the screen on the last frame drawn. That frame must be
	# fully black, not the old scene fading out.
	# The old scene leaves right after load() returns. Stop recording then, so the last
	# alpha is the frame shown during the load.
	var old_scene := Node.new()
	get_tree().root.add_child(old_scene)
	get_tree().current_scene = old_scene
	old_scene.tree_exiting.connect(get_tree().process_frame.disconnect.bind(_record_shown_alpha))
	get_tree().process_frame.connect(_record_shown_alpha)
	await _flow.go_to(SOLAR_SYSTEM)
	assert_float(_shown_alphas.back()).is_equal(1.0)


func test_fades_in_smoothly_after_a_slow_first_frame() -> void:
	# Setting up the new scene and compiling its shaders can take longer than the whole
	# fade. The step after has a long delta, which must not skip most of the fade in.
	# Drawing stays off: CI draws on a software renderer, where each frame of the game
	# scene alone is a step of about 0.25. The slow setup here is simulated anyway.
	# check.py runs tests at a fixed frame rate, where a frame that takes long still has
	# the usual delta, so the time scale makes the one long delta instead of a delay.
	RenderingServer.render_loop_enabled = false
	var set_up_slowly := func(_node: Node) -> void:
		Engine.time_scale = SLOW_FRAME_SECONDS / get_process_delta_time()
		get_tree().process_frame.connect(_end_slow_frame)
	get_tree().node_added.connect(set_up_slowly, CONNECT_ONE_SHOT)
	get_tree().process_frame.connect(_record_shown_alpha)
	await _flow.go_to(SOLAR_SYSTEM)
	# The fade's last step ends go_to in the same frame, so the next frame would show it.
	_record_shown_alpha()
	var largest_step := 0.0
	for i: int in range(1, _shown_alphas.size()):
		largest_step = maxf(largest_step, _shown_alphas[i - 1] - _shown_alphas[i])
	assert_float(largest_step).is_less(0.25)


# The time scale set in the frame that set up the scene stretches the next one.
func _end_slow_frame() -> void:
	if get_process_delta_time() >= SLOW_FRAME_SECONDS * 0.5:
		Engine.time_scale = 1.0
		get_tree().process_frame.disconnect(_end_slow_frame)


func test_shows_loading_while_the_next_scene_loads() -> void:
	# The old scene leaves right after load() returns: what shows then is the frame the
	# player looks at during the load.
	var old_scene := Node.new()
	get_tree().root.add_child(old_scene)
	get_tree().current_scene = old_scene
	var shown_during_load: Array[String] = []
	old_scene.tree_exiting.connect(func() -> void: shown_during_load.append(_shown_text()))
	await _flow.go_to(SOLAR_SYSTEM)
	assert_array(shown_during_load).contains_exactly(["Loading…"])


func test_fills_the_bar_in_steps_while_loading() -> void:
	# A bar that jumps from empty to full says nothing. Here it's drawn after every file.
	_flow.step_msec = 0
	var shown: Array[float] = []
	var record := func() -> void: shown.append(_bar().value)
	get_tree().process_frame.connect(record)
	await _flow.go_to(SOLAR_SYSTEM)
	get_tree().process_frame.disconnect(record)
	var steps: Array[float] = []
	for value: float in shown:
		if steps.is_empty() or value != steps.back():
			steps.append(value)
	assert_float(steps.back()).is_equal(1.0)
	assert_int(steps.size()).is_greater(10)
	var sorted := steps.duplicate()
	sorted.sort()
	assert_array(steps).is_equal(sorted)


func test_loads_the_scene_script_after_its_sub_scenes() -> void:
	# Compiling a script compiles every script it names. Loaded first, the scene's own
	# script compiled the whole game in one step, and the bar jumped from empty to full.
	var order := _flow._load_order(SOLAR_SYSTEM)
	assert_str(order.back()).is_equal("res://game/solar_system/solar_system.gd")
	# The same holds a level down, so a sub-scene's steps stay small too.
	assert_int(order.find("res://game/bus/bus.gd")).is_less(order.find("res://game/bus/bus.tscn"))
	assert_int(order.find("res://game/bus/bus_model.gd")).is_less(
		order.find("res://game/bus/bus.gd")
	)


func test_warms_up_one_new_shader_or_material_a_step() -> void:
	# Each first draw of a shader compiles it, so each step brings one new one. Objects on
	# shaders already drawn come along for free. A hidden one is drawn only for a material
	# nothing else has, so that doesn't compile when it first shows.
	var scene: Node3D = auto_free(Node3D.new())
	var shader := Shader.new()
	shader.code = "shader_type spatial;"
	var planet := _mesh_with(_shader_material(shader))
	var moon := _mesh_with(_shader_material(shader))
	var star := _mesh_with(StandardMaterial3D.new())
	var hidden := _mesh_with(StandardMaterial3D.new())
	hidden.visible = false
	var hidden_moon := _mesh_with(_shader_material(shader))
	hidden_moon.visible = false
	for mesh: MeshInstance3D in [planet, moon, star, hidden, hidden_moon]:
		scene.add_child(mesh)

	var steps := _flow._warm_up_steps(scene)

	assert_int(steps.size()).is_equal(3)
	assert_array(steps[0]).contains_exactly([planet, moon])
	assert_array(steps[1]).contains_exactly([star])
	assert_array(steps[2]).contains_exactly([hidden])


func _record_shown_alpha() -> void:
	_shown_alphas.append(_curtain().modulate.a)


func _curtain() -> Control:
	return _flow.get_child(0) as Control


func _mesh_with(material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = material
	return mesh


func _shader_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _bar() -> ProgressBar:
	return _curtain().find_children("*", "ProgressBar", true, false)[0] as ProgressBar


## The text on the loading card, if the card is fully shown.
func _shown_text() -> String:
	var curtain := _curtain()
	if not curtain.visible or curtain.modulate.a < 1.0:
		return ""
	for label: Node in curtain.find_children("*", "Label", true, false):
		if (label as Label).visible:
			return (label as Label).text
	return ""
