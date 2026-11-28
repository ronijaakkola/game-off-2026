extends GdUnitTestSuite
## A tutorial step's guide card has a Got it button only when the step asks for one, and
## pressing it says the card was read. A card given shorter text shrinks to fit it, as the
## one card the tutorial reuses for every step does. A card with no room on its side of
## the target, or that would cover the spot it keeps off, sits on the opposite one.

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


func test_a_card_given_shorter_text_shrinks_to_fit_it() -> void:
	var runner := scene_runner(SCENE)
	var card := runner.scene() as GuideCard
	card.target_rect = Rect2(400, 300, 40, 40)
	card.open()
	card.text = "Fresh."
	await runner.simulate_frames(5)
	var short_height := card.size.y

	card.text = (
		"Your route is set. Press and hold this button or {space} to charge the frameshift "
		+ "drive and leave for the Moon."
	)
	await runner.simulate_frames(5)
	assert_float(card.size.y).is_greater(short_height)

	card.text = "Fresh."
	await runner.simulate_frames(5)
	assert_float(card.size.y).is_equal_approx(short_height, 0.5)


func test_a_card_with_no_room_on_its_side_sits_on_the_opposite_one() -> void:
	var runner := scene_runner(SCENE)
	var card := runner.scene() as GuideCard
	card.text = "Your passenger wants to go to the Moon."
	card.side = GuideCard.Side.ABOVE
	# Too near the top for the card above it.
	var target := Rect2(500, 40, 40, 40)
	card.target_rect = target
	card.open()
	await runner.simulate_frames(30)
	assert_float(card.position.y).is_greater_equal(target.end.y)

	# With room above again, it goes back there.
	target = Rect2(500, 400, 40, 40)
	card.target_rect = target
	await runner.simulate_frames(5)
	assert_float(card.get_rect().end.y).is_less_equal(target.position.y)


func test_a_card_that_would_cover_its_avoided_spot_sits_on_the_opposite_side() -> void:
	var runner := scene_runner(SCENE)
	var card := runner.scene() as GuideCard
	card.text = "Your passenger wants to go to the Moon."
	card.side = GuideCard.Side.ABOVE
	var target := Rect2(500, 300, 40, 40)
	card.target_rect = target
	# The bus, up and to the left of the Moon, under where the card would sit above it.
	card.avoid_rect = Rect2(420, 230, 20, 20)
	card.open()
	await runner.simulate_frames(30)
	assert_float(card.position.y).is_greater_equal(target.end.y)

	# Once the bus is clear of it, it goes back above.
	card.avoid_rect = Rect2(100, 230, 20, 20)
	await runner.simulate_frames(5)
	assert_float(card.get_rect().end.y).is_less_equal(target.position.y)


func test_a_card_the_screen_edge_slides_onto_its_avoided_spot_sits_on_the_opposite_side() -> void:
	var runner := scene_runner(SCENE)
	var card := runner.scene() as GuideCard
	card.text = "Your passenger wants to go to the Moon."
	card.side = GuideCard.Side.ABOVE
	# Near the right edge: above it, the card slides left over the bus, though centred on
	# the Moon it would clear it.
	var target := Rect2(1100, 300, 40, 40)
	card.target_rect = target
	card.avoid_rect = Rect2(880, 230, 20, 20)
	card.open()
	await runner.simulate_frames(30)
	assert_float(card.position.y).is_greater_equal(target.end.y)
