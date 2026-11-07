extends GdUnitTestSuite
## The open planet's panel: its name, and a row for each passenger waiting there that
## follows the line as they arrive and board.

const SCENE := "res://game/solar_system/planet_panel.tscn"
const COMMUTER := preload("res://game/passengers/types/commuter.tres")

var _waiting: WaitingPassengers
var _home: Planet
var _away: Planet


func before_test() -> void:
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_home = Planet.new()
	_home.display_name = "Home"
	_away = Planet.new()
	_away.display_name = "Away"
	_away.orbit_radius = 6.0
	space.add_child(_home)
	space.add_child(_away)
	_waiting = auto_free(WaitingPassengers.new())
	_waiting.types = [COMMUTER]
	_waiting.max_per_planet = 3
	add_child(_waiting)
	# No one turns up by themselves during a test.
	_waiting.set_process(false)
	_waiting.set_planets([_home, _away])


func test_opens_hidden_and_shows_the_planet_and_who_waits_there() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as PlanetPanel
	panel.waiting = _waiting
	assert_bool(panel.visible).is_false()
	_waiting.add(_home)
	_waiting.add(_home)
	_waiting.add(_away)

	panel.open(_home)

	assert_bool(panel.visible).is_true()
	assert_str((runner.find_child("PlanetNameLabel") as Label).text).is_equal("Home")
	var rows := _rows(runner)
	assert_int(rows.size()).is_equal(2)
	var shown := rows.map(
		func(row: Node) -> Passenger: return (row as WaitingPassengerRow).passenger
	)
	# Longest waiting first.
	assert_array(shown).contains_exactly(_waiting.get_waiting(_home))
	assert_bool((runner.find_child("EmptyLabel") as Label).visible).is_false()
	var first := rows[0] as WaitingPassengerRow
	assert_str((first.find_child("DestinationLabel") as Label).text).is_equal("To Away")


func test_rows_follow_the_line_as_passengers_arrive_and_board() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as PlanetPanel
	panel.waiting = _waiting
	panel.open(_home)
	assert_int(_rows(runner).size()).is_equal(0)
	assert_bool((runner.find_child("EmptyLabel") as Label).visible).is_true()

	_waiting.add(_home)
	_waiting.add(_away)
	assert_int(_rows(runner).size()).is_equal(1)

	_waiting.take(_home, 1)
	assert_int(_rows(runner).size()).is_equal(0)
	assert_bool((runner.find_child("EmptyLabel") as Label).visible).is_true()


func test_close_button_asks_and_close_slides_out_and_hides() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as PlanetPanel
	panel.waiting = _waiting
	panel.open(_home)
	var monitor := monitor_signals(panel)

	(runner.find_child("CloseButton") as Button).pressed.emit()

	await assert_signal(monitor).is_emitted("close_pressed")
	# It only asks: the parent closes it.
	assert_object(panel.get_planet()).is_same(_home)
	panel.close()
	assert_object(panel.get_planet()).is_null()
	await await_millis(500)
	assert_bool(panel.visible).is_false()


func _rows(runner: GdUnitSceneRunner) -> Array[Node]:
	return (runner.find_child("WaitingRows") as Node).get_children()
