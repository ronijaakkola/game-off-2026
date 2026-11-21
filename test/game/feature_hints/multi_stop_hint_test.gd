extends GdUnitTestSuite
## In a run from the main menu, the bus waiting at a planet with passengers on board going
## to two different planets pauses the game with the multi-stop hint on the route bar; with
## them all going to one planet, it doesn't.

const SCENE := "res://game/solar_system/solar_system.tscn"
const MULTI_STOP_HINT := preload("res://game/feature_hints/multi_stop_hint.gd")


func before() -> void:
	SaveGame.use_test_files("multi_stop_hint")
	# Through the tutorial already, so the run starts docked with the lines going.
	SaveGame.mark_tutorial_done()


func after() -> void:
	SaveGame.use_player_files()


func before_test() -> void:
	SaveGame.forget_hints()


func after_test() -> void:
	get_tree().paused = false


func test_passengers_going_to_two_planets_show_the_hint() -> void:
	var runner := await _start()
	var hints := runner.find_child("FeatureHints") as FeatureHints
	_board(runner, ["Moon", "Ember"])
	await get_tree().create_timer(MULTI_STOP_HINT.SETTLE_SECONDS + 0.3).timeout

	assert_bool(hints.is_showing()).is_true()
	assert_bool(get_tree().paused).is_true()


func test_passengers_going_to_one_planet_show_no_hint() -> void:
	var runner := await _start()
	var hints := runner.find_child("FeatureHints") as FeatureHints
	_board(runner, ["Ember", "Ember"])
	await get_tree().create_timer(MULTI_STOP_HINT.SETTLE_SECONDS + 0.3).timeout

	assert_bool(hints.is_showing()).is_false()


func _start() -> GdUnitSceneRunner:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	return runner


# Seats a passenger on the bus for each planet in [param planets], going there.
func _board(runner: GdUnitSceneRunner, planets: Array[String]) -> void:
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var cabin := runner.find_child("Cabin") as Cabin
	for name: String in planets:
		var passenger := waiting.create(bus.get_docked_planet())
		passenger.destination = runner.find_child(name) as Planet
		cabin.board(passenger)
