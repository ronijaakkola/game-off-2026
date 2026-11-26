extends GdUnitTestSuite
## The mechanic past the first star system: a player who reaches Lyra without research has
## it open at once on its first stage, with no call, and the mechanic calls once they have
## delivered 3 passengers there, the answer opening the next stage.

const SCENE := "res://game/solar_system/solar_system.tscn"


func before() -> void:
	SaveGame.use_test_files("mechanic_call")


func after() -> void:
	SaveGame.use_player_files()


func test_in_lyra_research_is_open_at_once_and_the_call_3_deliveries_in_opens_stage_2() -> void:
	SaveGame.mark_tutorial_done()
	var run := {
		SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra"),
		"bus_planet": "Hither",
		"research_open": false,
	}
	SaveGame.write(run)
	SaveGame.continue_saved()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(5)
	var mechanic := runner.find_child("MechanicCall") as MechanicCall
	var research := (runner.find_child("ResearchLab") as ResearchLab).get_research()
	var goals := runner.find_child("Goals") as GoalTracker
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel

	assert_bool(research.is_opened()).is_true()
	assert_int(research.get_open_stages()).is_equal(1)
	assert_bool(mechanic.is_calling()).is_false()

	var deliveries := _deliveries_goal(goals)
	for i: int in mechanic.stage_deliveries - 1:
		deliveries.passenger_delivered(null)
	await runner.simulate_frames(5)
	assert_bool(mechanic.is_calling()).override_failure_message("rang too early").is_false()

	deliveries.passenger_delivered(null)
	await runner.simulate_frames(5)
	assert_bool(mechanic.is_calling()).is_true()

	for notice: Notice in (runner.find_child("Notices") as NoticeStack).get_notices():
		if notice.get_text() == NoticeStack.CALL_TEXT:
			notice.action_pressed.emit()
	assert_bool(panel.is_open()).is_true()
	panel.accept()

	await assert_func(research, "get_open_stages").wait_until(3000).is_equal(2)
	assert_bool(mechanic.is_calling()).is_false()


# The system's goal of delivering anyone.
func _deliveries_goal(goals: GoalTracker) -> DeliveryCountGoal:
	for goal: Goal in goals.get_goals():
		if goal is DeliveryCountGoal and not (goal as DeliveryCountGoal).type:
			return goal as DeliveryCountGoal
	return null
