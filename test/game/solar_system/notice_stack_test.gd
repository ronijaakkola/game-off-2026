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


# A tutorial step pushed its notice on top of the last step's leaving one, so it came in
# a notice too high and dropped as that one's gap closed.
func test_a_notice_replacing_a_leaving_one_comes_in_under_it() -> void:
	var stack := (load(STACK) as PackedScene).instantiate() as NoticeStack
	add_child(stack)
	auto_free(stack)
	var kept := stack.push("Fuel is running low.", Notice.Kind.WARNING)
	var old := stack.push("Right-click Terra to set a course there.", Notice.Kind.TUTORIAL)
	old.dismiss()

	var new := stack.push("Hold the Frameshift key to charge.", Notice.Kind.TUTORIAL)

	assert_array(stack.get_notices()).contains_exactly([old, new, kept])


func test_the_bus_full_notice_shows_once_and_another_try_prolongs_it() -> void:
	var stack := (load(STACK) as PackedScene).instantiate() as NoticeStack
	add_child(stack)
	auto_free(stack)
	var notice := stack.tell_bus_full()
	await await_millis(int(NoticeStack.BUS_FULL_SECONDS * 1000.0 * 0.6))

	assert_object(stack.tell_bus_full()).is_same(notice)
	assert_int(stack.get_child_count()).is_equal(1)
	# Past when the first try's time ran out, the second's still runs.
	await await_millis(int(NoticeStack.BUS_FULL_SECONDS * 1000.0 * 0.6))
	assert_bool(notice.is_leaving()).is_false()
	await assert_signal(notice).wait_until(2000).is_emitted("dismissed")
	# Once it has gone, the next try brings a new one.
	assert_object(stack.tell_bus_full()).is_not_same(notice)
