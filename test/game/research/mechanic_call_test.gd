extends GdUnitTestSuite
## The mechanic past the first star system: a player who reaches Lyra without research has
## it open at once on its first stage, with no call, and the mechanic calls once they have
## delivered 3 passengers there, the answer opening the next stage. In Sol, whose star
## swells, the swell holds at rest until that call, which warns of it in Sol's own words,
## and starts as it closes; a run continued there after the call has it swelling.

const SCENE := "res://game/solar_system/solar_system.tscn"


func before() -> void:
	SaveGame.use_test_files("mechanic_call")


func after() -> void:
	SaveGame.use_player_files()


func after_test() -> void:
	Engine.time_scale = 1.0


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


func test_in_sol_the_call_warns_of_the_swell_and_starts_it() -> void:
	var runner := _continue_in_sol(2)
	await runner.simulate_frames(5)
	var mechanic := runner.find_child("MechanicCall") as MechanicCall
	var sol := (runner.find_child("StarMap") as StarMap).get_current()
	var goals := runner.find_child("Goals") as GoalTracker
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	await _play(runner, sol.swell_rest_seconds + 10.0)
	assert_float(sol.get_swell()).override_failure_message("swelled before the call").is_zero()

	var deliveries := _deliveries_goal(goals)
	for i: int in mechanic.stage_deliveries:
		deliveries.passenger_delivered(null)
	await runner.simulate_frames(5)
	for notice: Notice in (runner.find_child("Notices") as NoticeStack).get_notices():
		if notice.get_text() == NoticeStack.CALL_TEXT:
			notice.action_pressed.emit()
	assert_bool(panel.is_open()).is_true()
	assert_array(_texts(panel)).contains([sol.mechanic_call])
	panel.accept()
	await assert_func(mechanic, "is_calling").wait_until(3000).is_false()

	await _play(runner, sol.swell_warning_seconds + 1.0)
	assert_float(sol.get_swell()).is_greater(0.0)


func test_continued_in_sol_after_the_call_the_star_swells() -> void:
	var runner := _continue_in_sol(3)
	await runner.simulate_frames(5)
	var sol := (runner.find_child("StarMap") as StarMap).get_current()
	await _play(runner, sol.swell_warning_seconds + 1.0)
	assert_float(sol.get_swell()).is_greater(0.0)


# A run continued in Sol, docked at Mars, with [param stages] research stages open: 2 as
# the bus arrives from Lyra, 3 once Sol's call has opened its own.
func _continue_in_sol(stages: int) -> GdUnitSceneRunner:
	SaveGame.mark_tutorial_done()
	var run := {
		SavedStarMap.KEY: SavedStarMap.make(3, false, "Sol"),
		"bus_planet": "Mars",
		"research_open": true,
		"research_stages": stages,
	}
	SaveGame.write(run)
	SaveGame.continue_saved()
	return scene_runner(SCENE)


# Plays [param seconds] of game time, a sixth of a second a frame.
func _play(runner: GdUnitSceneRunner, seconds: float) -> void:
	Engine.time_scale = 10.0
	await runner.simulate_frames(ceili(seconds * 6.0))
	Engine.time_scale = 1.0


# Every line of text the panel shows.
func _texts(panel: Node) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in panel.find_children("*", "RichTextLabel", true, false):
		texts.append((node as RichTextLabel).text)
	for node: Node in panel.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return texts


# The system's goal of delivering anyone.
func _deliveries_goal(goals: GoalTracker) -> DeliveryCountGoal:
	for goal: Goal in goals.get_goals():
		if goal is DeliveryCountGoal and not (goal as DeliveryCountGoal).type:
			return goal as DeliveryCountGoal
	return null
