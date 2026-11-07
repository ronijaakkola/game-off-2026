extends GdUnitTestSuite
## MorphLabel's text swaps and morphs, driven with a fixed step so each test is quick.

const STEP := 0.05
# Far longer than any morph in these tests.
const MAX_STEPS := 200

var _label: MorphLabel
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	if Settings.reduce_motion:
		Settings.reduce_motion = false
	_label = auto_free(MorphLabel.new()) as MorphLabel
	_label.size = Vector2(200.0, 20.0)
	_label.text = "Looking at empty space"
	add_child(_label)


func after_test() -> void:
	# Assigning re-saves the developer's own settings file, so only when it changed.
	if Settings.reduce_motion != _reduce_motion:
		Settings.reduce_motion = _reduce_motion


func test_a_morph_shows_the_new_text_at_once_and_hides_the_label_until_it_ends() -> void:
	_label.morph_to("Wants a drink")
	assert_str(_label.text).is_equal("Wants a drink")
	assert_bool(_label.is_morphing()).is_true()
	assert_float(_label.self_modulate.a).is_equal(0.0)
	_finish()
	assert_bool(_label.is_morphing()).is_false()
	assert_float(_label.self_modulate.a).is_equal(1.0)


func test_a_morph_restarted_halfway_gives_back_the_labels_own_self_modulate() -> void:
	var tint := Color(1.0, 0.5, 0.5, 0.8)
	_label.self_modulate = tint
	_label.morph_to("Wants a drink")
	_label._process(STEP)
	_label.morph_to("Munching a snack")
	assert_str(_label.text).is_equal("Munching a snack")
	_finish()
	assert_object(_label.self_modulate).is_equal(tint)


func test_from_an_empty_text_it_swaps_at_once() -> void:
	_label.text = ""
	_label.morph_to("Wants a drink")
	assert_str(_label.text).is_equal("Wants a drink")
	assert_bool(_label.is_morphing()).is_false()


func test_with_reduce_motion_it_swaps_at_once() -> void:
	Settings.reduce_motion = true
	_label.morph_to("Wants a drink")
	assert_str(_label.text).is_equal("Wants a drink")
	assert_bool(_label.is_morphing()).is_false()
	assert_float(_label.self_modulate.a).is_equal(1.0)


# Steps the morph until it ends, with a cap.
func _finish() -> void:
	for _step: int in MAX_STEPS:
		if not _label.is_morphing():
			return
		_label._process(STEP)
