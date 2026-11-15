extends GdUnitTestSuite
## A feature hint pauses the game on its target until the player presses Got it, then
## never shows again until the hints are forgotten. One passed over for a hidden target
## shows the next time.

const GUIDE_CARD := preload("res://ui/guide_card/guide_card.tscn")
# The hints seen go to a file of the suite's own, never the player's.
const TEST_HINTS := "user://test_feature_hints.cfg"

var _window_size: Vector2i
var _hints: FeatureHints
var _guide: GuideCard
var _target: Control


func before() -> void:
	SaveGame.hints_path = TEST_HINTS
	# Headless, the window is 64×64 and the canvas_items stretch would scale every click.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	SaveGame.forget_hints()
	SaveGame.hints_path = SaveGame.HINTS_PATH
	get_tree().root.size = _window_size


func before_test() -> void:
	SaveGame.forget_hints()
	var root := auto_free(Control.new()) as Control
	root.size = Vector2(1152, 648)
	_target = Control.new()
	_target.position = Vector2(500, 500)
	_target.size = Vector2(120, 10)
	root.add_child(_target)
	_guide = GUIDE_CARD.instantiate() as GuideCard
	root.add_child(_guide)
	_hints = FeatureHints.new()
	_hints.guide = _guide
	root.add_child(_hints)
	add_child(root)


func after_test() -> void:
	get_tree().paused = false


func test_shows_once_and_got_it_resumes() -> void:
	_hints.offer(&"heat_zone", _target)
	await await_idle_frame()
	assert_bool(_hints.is_showing()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(_guide.visible).is_true()
	await get_tree().create_timer(Audio.MUFFLE_IN_SECONDS + 0.1).timeout
	assert_float(Audio.get_muffle()).is_equal_approx(1.0, 0.01)

	await _press_got_it()
	await get_tree().create_timer(Audio.MUFFLE_OUT_SECONDS + 0.1).timeout
	assert_float(Audio.get_muffle()).is_equal_approx(0.0, 0.01)

	assert_bool(_hints.is_showing()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(SaveGame.has_seen_hint(&"heat_zone")).is_true()
	_hints.offer(&"heat_zone", _target)
	assert_bool(_hints.is_showing()).is_false()

	# The debug panel's Forget hints; deleting the save data happens in the main menu, so
	# the next game scene reads the hints afresh.
	_hints._debug_forget_hints()
	assert_bool(SaveGame.has_seen_hint(&"heat_zone")).is_false()
	_hints.offer(&"heat_zone", _target)
	assert_bool(_hints.is_showing()).is_true()


func test_a_hidden_target_waits_for_the_next_time() -> void:
	_target.hide()
	_hints.offer(&"heat_zone", _target)
	assert_bool(_hints.is_showing()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(SaveGame.has_seen_hint(&"heat_zone")).is_false()

	_target.show()
	_hints.offer(&"heat_zone", _target)
	assert_bool(_hints.is_showing()).is_true()


func _press_got_it() -> void:
	# Opening takes a moment; Got it counts only once it is open. gdUnit's own waits stall
	# while the tree is paused, and a scene tree timer doesn't.
	await get_tree().create_timer(0.3).timeout
	var got_it := _guide.find_child("GotItButton") as Button
	assert_bool(got_it.is_visible_in_tree()).is_true()
	got_it.pressed.emit()
	await await_idle_frame()
