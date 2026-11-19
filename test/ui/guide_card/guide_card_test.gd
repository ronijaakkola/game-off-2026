extends GdUnitTestSuite
## A tutorial step's guide card has a Got it button only when the step asks for one, and
## pressing it says the card was read.

const SCENE := "res://ui/guide_card/guide_card.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64 and the canvas_items stretch would scale every click.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func test_got_it_shows_only_when_asked_and_acknowledges() -> void:
	var runner := scene_runner(SCENE)
	var card := runner.scene() as GuideCard
	card.text = "You are driving this bus."
	card.target_rect = Rect2(400, 300, 40, 40)
	card.side = GuideCard.Side.RIGHT
	card.open()
	await runner.simulate_frames(20)
	var got_it := runner.find_child("GotItButton") as Button
	assert_bool(got_it.is_visible_in_tree()).is_false()

	card.got_it = true
	await runner.simulate_frames(2)
	assert_bool(got_it.is_visible_in_tree()).is_true()
	monitor_signals(card)
	runner.set_mouse_position(got_it.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await assert_signal(card).is_emitted("acknowledged")
