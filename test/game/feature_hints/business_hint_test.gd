extends GdUnitTestSuite
## In a run from the main menu, the first Business passenger waiting in the dock panel
## pauses the game with the business hint beside their row, once the row is in.

const SCENE := "res://game/solar_system/solar_system.tscn"
const BUSINESS_HINT := preload("res://game/feature_hints/business_hint.gd")
const BUSINESS := preload("res://game/passengers/types/business.tres")
# A run started this way saves, so the suite saves to files of its own.
const TEST_SAVE := "user://test_business_hint_save.json"
const TEST_TUTORIAL := "user://test_business_hint_tutorial.cfg"
const TEST_HINTS := "user://test_business_hint_hints.cfg"


func before() -> void:
	SaveGame.path = TEST_SAVE
	SaveGame.tutorial_path = TEST_TUTORIAL
	SaveGame.hints_path = TEST_HINTS
	# Through the tutorial already, so the run starts docked with the lines going.
	SaveGame.mark_tutorial_done()


func after() -> void:
	SaveGame.delete()
	SaveGame.forget_tutorial()
	SaveGame.forget_hints()
	SaveGame.path = SaveGame.PATH
	SaveGame.tutorial_path = SaveGame.TUTORIAL_PATH
	SaveGame.hints_path = SaveGame.HINTS_PATH


func after_test() -> void:
	get_tree().paused = false


func test_first_business_passenger_waiting_shows_the_hint() -> void:
	SaveGame.forget_hints()
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var hints := runner.find_child("FeatureHints") as FeatureHints
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var planet := bus.get_docked_planet()
	var passenger := waiting.create(planet)
	passenger.type = BUSINESS
	waiting.restore(planet, [passenger] as Array[Passenger], 0)

	await get_tree().create_timer(BUSINESS_HINT.SETTLE_SECONDS + 0.5).timeout

	assert_bool(hints.is_showing()).is_true()
	assert_bool(get_tree().paused).is_true()
