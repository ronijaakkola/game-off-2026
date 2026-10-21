extends GdUnitTestSuite

const SceneFlowScript := preload("res://core/scene_flow/scene_flow.gd")
const GAME := "res://game/game.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

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
	_shown_alphas.clear()
	RenderingServer.render_loop_enabled = true
	# A failed transition must not leave input off for the rest of the suite.
	get_tree().root.set_disable_input(false)
	get_tree().paused = false
	get_tree().unload_current_scene()


func test_changes_the_current_scene() -> void:
	await _flow.go_to(GAME)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(GAME)


func test_blocks_input_only_while_fading() -> void:
	_flow.go_to(GAME)
	assert_bool(get_tree().root.is_input_disabled()).is_true()
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


func test_ignores_a_call_during_a_transition() -> void:
	_flow.go_to(GAME)
	await _flow.go_to("res://does_not_exist.tscn")
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(GAME)


func test_the_next_scene_starts_unpaused() -> void:
	get_tree().paused = true
	_flow.go_to(GAME)
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
	await _flow.go_to(GAME)
	assert_float(_shown_alphas.back()).is_equal(1.0)


func test_fades_in_smoothly_after_a_slow_first_frame() -> void:
	# Setting up the new scene and compiling its shaders can take longer than the whole
	# fade. The step after has a long delta, which must not skip most of the fade in.
	# Drawing stays off: CI draws on a software renderer, where each frame of the game
	# scene alone is a step of about 0.25. The slow setup here is simulated anyway.
	RenderingServer.render_loop_enabled = false
	var set_up_slowly := func(_node: Node) -> void: OS.delay_msec(400)
	get_tree().node_added.connect(set_up_slowly, CONNECT_ONE_SHOT)
	get_tree().process_frame.connect(_record_shown_alpha)
	await _flow.go_to(GAME)
	var largest_step := 0.0
	for i: int in range(1, _shown_alphas.size()):
		largest_step = maxf(largest_step, _shown_alphas[i - 1] - _shown_alphas[i])
	assert_float(largest_step).is_less(0.25)


func _record_shown_alpha() -> void:
	_shown_alphas.append((_flow.get_child(0) as ColorRect).color.a)
