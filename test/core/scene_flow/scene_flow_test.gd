extends GdUnitTestSuite

const SceneFlowScript := preload("res://core/scene_flow/scene_flow.gd")
const GAME := "res://game/game.tscn"

var _flow: SceneFlowScript
var _runner_scene: Node


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
	await _flow.go_to(GAME)
	assert_bool(get_tree().paused).is_false()
