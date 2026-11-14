extends GdUnitTestSuite
## The player sees a card for each passenger on board and serves a request from it.

const SCENE := "res://game/passengers/passenger_panel.tscn"
const PREVIEW := "res://test/previews/passenger_panel_preview.tscn"
const STUDIO := preload("res://game/passengers/portrait_studio.tscn")

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
	assert_int(_cards_in(cards).size()).is_equal(1)
	var card := _cards_in(cards)[0]
	assert_str((card.find_child("NameLabel") as Label).text).is_equal(passenger.name)
	assert_str((runner.find_child("PlanetLabel") as Label).text).is_equal("Ember")

	# Done coming in.
	await runner.simulate_frames(30, 30)
	cabin.stop_at(planet)
	# It shows their rating and stays in place almost until it has lingered its time.
	await await_millis(roundi(PassengerCard.LINGER_SECONDS * 1000.0) - 300)
	assert_bool((card as PassengerCard).is_rated()).is_true()
	var panel := card.find_child("Panel") as Control
	assert_float(_shift_of(panel, card)).is_equal(0.0)
	# Then it slides out to the left and folds away before it goes.
	await assert_func(self, "_slid_out", [panel, card]).wait_until(2000).is_true()
	assert_int(_cards_in(cards).size()).is_equal(1)
	# Its group's header folds away after it.
	await runner.simulate_frames(40, 30)
	assert_int(cards.get_child_count()).is_equal(0)


func test_a_card_shows_a_portrait_and_gives_it_back_when_the_passenger_gets_off() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var studio := STUDIO.instantiate() as PortraitStudio
	runner.scene().add_child(studio)
	(runner.scene() as PassengerPanel).portrait_studio = studio
	var planet: Planet = auto_free(Planet.new())
	cabin.board(_passenger(planet, 1000.0))
	await runner.simulate_frames(2)

	var photo := runner.find_child("PassengerPhoto") as PassengerPhoto
	assert_object(photo.get_photo()).is_not_null()
	assert_int(studio.get_portrait_count()).is_equal(1)

	cabin.stop_at(planet)
	await await_millis(roundi(PassengerCard.LINGER_SECONDS * 1000.0))
	await runner.simulate_frames(40, 30)
	assert_int(studio.get_portrait_count()).is_equal(0)


func test_a_boarding_card_opens_its_place_and_slides_in_from_the_left() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	await runner.simulate_frames(1)

	cabin.board(_passenger(auto_free(Planet.new()), 1000.0))

	var card := _cards_in(runner.find_child("Cards"))[0]
	var panel := card.find_child("Panel") as Control
	# It starts past the left edge of the screen, its place in the list closed.
	assert_float(panel.global_position.x + panel.size.x).is_less(0.0)
	assert_float(card.custom_minimum_size.y).is_equal(0.0)
	await runner.simulate_frames(30, 30)
	assert_float(_shift_of(panel, card)).is_equal(0.0)
	assert_float(card.custom_minimum_size.y).is_equal(panel.size.y + PassengerCard.GAP)


func test_holding_serve_on_a_card_serves_the_request() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var passenger := _passenger(auto_free(Planet.new()), 0.05)
	cabin.board(passenger)
	cabin.docked = false
	# Long enough for the card to come in: it takes no clicks while its place opens.
	await runner.simulate_frames(20, 20)
	assert_object(passenger.request).is_not_null()

	var button := runner.find_child("ServeButton") as Button
	await runner.simulate_frames(2)
	assert_bool(button.is_visible_in_tree()).is_true()
	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(10, 20)
	# Held a moment, only part of it is served, and the button fills that far.
	assert_object(passenger.request).is_not_null()
	assert_float((button as ServeButton).progress).is_greater(0.0)
	await runner.simulate_frames(20, 100)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

	assert_object(passenger.request).is_null()
	assert_str((runner.find_child("ActivityLabel") as Label).text).is_equal("Munching")


func test_each_destination_s_group_shows_an_icon_in_its_colour() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var colors: Array[Color] = [Color.ORANGE, Color.TEAL]
	for color: Color in colors:
		var planet: Planet = auto_free(Planet.new())
		planet.icon_color = color
		cabin.board(_passenger(planet, 1000.0))
	await runner.simulate_frames(2)

	var icons := (runner.find_child("Cards") as Control).find_children(
		"DestinationPlanetIcon", "", true, false
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
	assert_int(_cards_in(cards).size()).is_equal(8)
	var serving := 0
	for button: Node in cards.find_children("ServeButton", "", true, false):
		if (button as Button).is_visible_in_tree():
			serving += 1
	assert_int(serving).is_equal(3)
	# Every card is as wide as the others, whatever its name or request.
	var panels := cards.find_children("Panel", "PanelContainer", true, false)
	for panel: Node in panels:
		assert_float((panel as Control).size.x).is_equal((panels[0] as Control).size.x)


func test_a_card_s_photo_background_takes_their_race_s_backdrop_colour() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var away: Planet = auto_free(Planet.new())
	var passenger := _passenger(away, 1000.0)
	passenger.race = Race.Type.GREEN
	cabin.board(passenger)
	await runner.simulate_frames(2)

	var backdrop := (runner.find_child("Backdrop") as ColorRect).material as ShaderMaterial
	assert_that(backdrop.get_shader_parameter(&"backdrop_color")).is_equal(
		Race.BACKDROP_COLORS[Race.Type.GREEN]
	)


func test_a_card_s_kick_button_fades_in_outside_the_board() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	cabin.board(_passenger(auto_free(Planet.new()), 1000.0))
	await runner.simulate_frames(30, 30)

	var panel := runner.find_child("Panel") as Control
	runner.simulate_mouse_move(panel.get_global_rect().get_center())
	await runner.await_input_processed()
	await runner.simulate_frames(2)
	var options := runner.find_child("Options") as Control
	var kick := runner.find_child("KickButton") as Control
	var start := options.position.x
	await runner.simulate_frames(20, 20)
	# It fades in where it stays, clear of the board's edge.
	assert_bool(options.visible).is_true()
	assert_float(options.modulate.a).is_equal(1.0)
	assert_float(options.position.x).is_equal(start)
	var board := runner.find_child("Board") as Control
	assert_float(kick.global_position.x).is_greater(board.global_position.x + board.size.x)


func test_cards_group_by_destination_in_the_order_the_planets_came_up() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var terra: Planet = auto_free(Planet.new())
	terra.name = "Terra"
	var frost: Planet = auto_free(Planet.new())
	frost.name = "Frost"
	var first := _passenger(terra, 1000.0)
	var second := _passenger(frost, 1000.0)
	var third := _passenger(terra, 1000.0)
	for passenger: Passenger in [first, second, third]:
		cabin.board(passenger)
	await runner.simulate_frames(2)

	var groups := (runner.find_child("Cards") as Control).get_children()
	assert_int(groups.size()).is_equal(2)
	assert_str((groups[0].find_child("PlanetLabel") as Label).text).is_equal("Terra")
	assert_str((groups[0].find_child("CountLabel") as Label).text).is_equal("2")
	assert_array(_names(groups[0])).is_equal([first.name, third.name])
	assert_str((groups[1].find_child("PlanetLabel") as Label).text).is_equal("Frost")
	assert_array(_names(groups[1])).is_equal([second.name])


func test_a_passenger_boarding_while_arrivals_are_held_comes_in_once_let_go() -> void:
	var runner := scene_runner(SCENE)
	var cabin := _cabin(runner)
	var planet: Planet = auto_free(Planet.new())
	runner.set_property("arrivals_held", true)

	cabin.board(_passenger(planet, 1000.0))
	await runner.simulate_frames(2)
	var cards := runner.find_child("Cards") as Control
	assert_int(_cards_in(cards).size()).is_equal(0)

	runner.set_property("arrivals_held", false)
	await runner.simulate_frames(2)
	assert_int(_cards_in(cards).size()).is_equal(1)


func _names(group: Node) -> Array[String]:
	var names: Array[String] = []
	for card: PassengerCard in _cards_in(group):
		names.append((card.find_child("NameLabel") as Label).text)
	return names


func _cards_in(node: Node) -> Array[PassengerCard]:
	var cards: Array[PassengerCard] = []
	cards.assign(node.find_children("*", "PassengerCard", true, false))
	return cards


func _slid_out(panel: Control, card: Control) -> bool:
	return _shift_of(panel, card) < 0.0


# How far right of its place in the card the panel sits, in pixels.
func _shift_of(panel: Control, card: Control) -> float:
	return panel.global_position.x - card.global_position.x


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
