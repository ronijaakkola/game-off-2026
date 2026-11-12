extends GdUnitTestSuite
## The notice stack's notices, stepped in real time.

const STACK := "res://game/solar_system/notice_stack.tscn"


func test_a_postponed_notice_dismissed_while_hidden_never_comes_in() -> void:
	var stack := (load(STACK) as PackedScene).instantiate() as NoticeStack
	add_child(stack)
	auto_free(stack)
	stack.hide()
	var notice := stack.push("Fuel is running low.", Notice.Kind.WARNING)
	var card := notice.find_child("Card") as Control
	notice.dismiss()

	stack.show()
	var brightest := 0.0
	while is_instance_valid(notice):
		brightest = maxf(brightest, card.modulate.a)
		await get_tree().process_frame

	assert_float(brightest).is_equal(0.0)
	assert_int(stack.get_child_count()).is_equal(0)


func test_a_notice_answered_into_a_pause_still_leaves() -> void:
	var stack := (load(STACK) as PackedScene).instantiate() as NoticeStack
	add_child(stack)
	auto_free(stack)
	var notice := stack.announce_transmission()
	# The answer opens a transmission, which pauses the game in the same click.
	notice.action_pressed.connect(func() -> void: get_tree().paused = true)
	(notice.find_child("ActionButton") as Button).pressed.emit()

	var frames := 0
	while is_instance_valid(notice) and frames < 120:
		frames += 1
		await get_tree().process_frame
	get_tree().paused = false

	assert_bool(is_instance_valid(notice)).is_false()
