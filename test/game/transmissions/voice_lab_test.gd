extends GdUnitTestSuite


func test_the_lab_shows_a_race_s_settings_and_speaks() -> void:
	var runner := scene_runner("res://game/transmissions/voice_lab.tscn")
	var lab := runner.scene()
	var races := runner.find_child("RaceOption") as OptionButton
	assert_int(races.item_count).is_equal(Race.Type.values().size())
	var params := runner.find_child("Params") as Container
	assert_bool(params.get_child_count() > 8).is_true()
	assert_bool((runner.find_child("NoVoice") as Control).visible).is_false()
	# A race with no voice has nothing to tune.
	races.select(races.get_item_index(Race.Type.GREEN))
	lab._on_race_option_item_selected(0)
	assert_bool((runner.find_child("NoVoice") as Control).visible).is_true()
	# Back to Blue, and Speak opens the real modal.
	races.select(races.get_item_index(Race.Type.BLUE))
	lab._on_race_option_item_selected(0)
	lab._on_speak_button_pressed()
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	assert_bool(panel.is_open()).is_true()
	assert_object(panel.get_voice().voice).is_not_null()
