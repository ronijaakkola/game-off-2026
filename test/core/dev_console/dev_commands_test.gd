extends GdUnitTestSuite

const GAME := "res://game/game.tscn"

var _runner_scene: Node


func before() -> void:
	# In the editor, gdUnit's runner is the current scene, and changing scenes would free
	# it mid-run. Headless, there is no current scene.
	_runner_scene = get_tree().current_scene
	get_tree().current_scene = null


func after() -> void:
	get_tree().current_scene = _runner_scene


func after_test() -> void:
	# goto runs on the live SceneFlow; let its fade-in end before the next suite.
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()
	get_tree().unload_current_scene()


func test_goto_changes_the_scene() -> void:
	# Named by path: only dev_commands.gd may name LimboConsole.
	get_tree().root.get_node(^"LimboConsole").call("execute_command", "goto " + GAME)
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(GAME)
