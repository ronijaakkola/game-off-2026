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
