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

	cabin.arrive_at(planet)
	await runner.simulate_frames(2)
	assert_int(cards.get_child_count()).is_equal(0)


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


func test_each_card_shows_an_icon_in_its_own_destination_colour() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var colors: Array[Color] = [Color.ORANGE, Color.TEAL]
	for color: Color in colors:
		var planet: Planet = auto_free(Planet.new())
		planet.icon_color = color
		cabin.board(_passenger(planet, 1000.0))
	await runner.simulate_frames(2)

	var icons := (runner.find_child("Cards") as Control).find_children(
		"DestinationIcon", "", true, false
	)
	assert_int(icons.size()).is_equal(2)
	for i: int in icons.size():
		var icon := icons[i] as PlanetIcon
		assert_bool(icon.is_visible_in_tree()).is_true()
		var shown: Color = (icon.material as ShaderMaterial).get_shader_parameter(&"color")
		assert_that(shown).is_equal(colors[i])


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
