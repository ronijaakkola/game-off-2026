extends GdUnitTestSuite
## In a run from the main menu, the first Business passenger waiting in the dock panel
## pauses the game with the business hint beside their row, once the row is in.

const SCENE := "res://game/solar_system/solar_system.tscn"
const BUSINESS_HINT := preload("res://game/feature_hints/business_hint.gd")
const BUSINESS := preload("res://game/passengers/types/business.tres")


func before() -> void:
	SaveGame.use_test_files("business_hint")
	# Through the tutorial already, so the run starts docked with the lines going.
	SaveGame.mark_tutorial_done()


func after() -> void:
	SaveGame.use_player_files()


func after_test() -> void:
	get_tree().paused = false


func test_first_business_passenger_waiting_shows_the_hint() -> void:
	SaveGame.forget_hints()
	# Seen already, so it doesn't open ahead of the business hint.
	SaveGame.mark_hint_seen(&"goals")
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	await _answer_first_shift_call(runner)
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


# A new run opens on The Boss's call with the panels hidden: answered, they come back.
func _answer_first_shift_call(runner: GdUnitSceneRunner) -> void:
	var notices := runner.find_child("Notices") as NoticeStack
	await assert_func(self, "_has_notice", [notices]).wait_until(5000).is_true()
	notices.get_notices()[0].action_pressed.emit()
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	panel.skip()
	panel.accept()
	await panel.answered
	await (
		assert_func(runner.find_child("TopRight") as Control, "is_visible")
		. wait_until(2000)
		. is_true()
	)


func _has_notice(notices: NoticeStack) -> bool:
	return not notices.get_notices().is_empty()
