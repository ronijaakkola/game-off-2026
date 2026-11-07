extends GdUnitTestSuite
## The player sees a card for each passenger on board and serves a request from it.

const SCENE := "res://game/passengers/passenger_panel.tscn"
const PREVIEW := "res://test/previews/passenger_panel_preview.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64 and the canvas_items stretch would scale every click.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func test_a_boarding_passenger_gets_a_card_and_loses_it_on_getting_off() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var planet: Planet = auto_free(Planet.new())
	planet.name = "Ember"
	var passenger := _passenger(planet, 1000.0)

	cabin.board(passenger)
	await runner.simulate_frames(2)

	var cards := runner.find_child("Cards") as Control
	assert_int(cards.get_child_count()).is_equal(1)
	var card := cards.get_child(0)
	assert_str((card.find_child("NameLabel") as Label).text).is_equal(passenger.name)
	assert_str((card.find_child("DestinationLabel") as Label).text).contains("Ember")

	cabin.stop_at(planet)
	# It slides out and folds away before it goes.
	await runner.simulate_frames(2)
	assert_int(cards.get_child_count()).is_equal(1)
	await runner.simulate_frames(30, 30)
	assert_int(cards.get_child_count()).is_equal(0)


func test_a_boarding_card_slides_in_from_the_right() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	await runner.simulate_frames(1)

	cabin.board(_passenger(auto_free(Planet.new()), 1000.0))
	await runner.simulate_frames(1)

	var panel := runner.find_child("Panel") as Control
	var width := get_tree().root.get_visible_rect().size.x
	assert_float(panel.position.x).is_greater(width * 0.5)
	await runner.simulate_frames(30, 30)
	assert_float(panel.position.x).is_equal(0.0)


func test_clicking_serve_on_a_card_serves_the_request() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var passenger := _passenger(auto_free(Planet.new()), 0.05)
	cabin.board(passenger)
	await runner.simulate_frames(10, 20)
	assert_object(passenger.request).is_not_null()

	var button := runner.find_child("ServeButton") as Button
	await runner.simulate_frames(2)
	assert_bool(button.is_visible_in_tree()).is_true()
	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

	assert_object(passenger.request).is_null()
	assert_str((runner.find_child("ActivityLabel") as Label).text).is_equal("Munching")


func test_the_preview_shows_a_full_cabin_with_three_requests() -> void:
	var runner := scene_runner(PREVIEW)
	await runner.simulate_frames(2)

	var cards := runner.find_child("Cards") as Control
	assert_int(cards.get_child_count()).is_equal(8)
	var serving := 0
	for button: Node in cards.find_children("ServeButton", "", true, false):
		if (button as Button).is_visible_in_tree():
			serving += 1
	assert_int(serving).is_equal(3)


func _cabin(runner: GdUnitSceneRunner) -> Cabin:
	var cabin := Cabin.new()
	runner.scene().add_child(cabin)
	runner.set_property("cabin", cabin)
	return cabin


func _passenger(to: Planet, need_after: float) -> Passenger:
	var snack := Need.new()
	snack.id = &"snack"
	snack.serve_label = "Hand a snack"
	snack.served_line = "Munching"
	snack.served_seconds = 30.0
	snack.min_interval = need_after
	snack.max_interval = need_after
	var kind := PassengerType.new()
	kind.needs = [snack]
	return Passenger.new(kind, to, 100.0, 40.0)
