extends GdUnitTestSuite
## The end of a star system: once every goal has held for 5 s The Boss calls with the
## promotion, and its answer "Jump to new system" jumps the bus to the next system from
## wherever it is, leaving whoever is on board behind. The goals the promotion took stay on
## the goal panel, ticked, until the next system's goals replace them.

const SCENE := "res://game/solar_system/solar_system.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")


## A goal that is always met.
class MetGoal:
	extends Goal

	func is_met() -> bool:
		return true


# A jump that failed under the loading screen must not leave the next test paused.
func after_test() -> void:
	get_tree().paused = false
	await assert_func(SceneFlow, "is_busy").wait_until(5000).is_false()
	get_tree().root.set_disable_input(false)


func before() -> void:
	SaveGame.use_test_files("progression")


func after() -> void:
	SaveGame.use_player_files()


func test_the_boss_calls_once_the_goals_hold_and_answered_jumps_with_anyone_on_board() -> void:
	SaveGame.mark_tutorial_done()
	# A continued run, so The Boss's first-shift call doesn't ring over this one.
	SaveGame.write({})
	SaveGame.continue_saved()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var goals := runner.find_child("Goals") as GoalTracker
	for goal: Goal in goals.get_goals():
		goals.remove(goal)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var cabin := runner.find_child("Cabin") as Cabin
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var passenger := waiting.create(bus.get_docked_planet())
	cabin.board(passenger)
	var boss := runner.find_child("GoalsMetCall") as GoalsMetCall
	var notices := runner.find_child("Notices") as NoticeStack

	goals.add(MetGoal.new())

	await runner.simulate_frames(40, 100)
	assert_bool(boss.is_ringing()).is_false()
	await runner.simulate_frames(15, 100)
	assert_bool(boss.is_ringing()).is_true()
	var call: Notice = null
	for notice: Notice in notices.get_notices():
		if notice.get_text() == NoticeStack.CALL_TEXT:
			call = notice
	assert_object(call).is_not_null()
	call.action_pressed.emit()
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	assert_bool(panel.is_open()).is_true()
	var answer := panel.find_child("AcceptButton", true, false) as Button
	assert_str(answer.text).is_equal(GoalsMetCall.JUMP_ANSWER)
	var stay := panel.find_child("DeclineButton", true, false) as Button
	assert_bool(stay.visible).is_true()
	assert_str(stay.text).is_equal(GoalsMetCall.STAY_ANSWER)
	var jump := runner.find_child("SystemJump") as SystemJump
	monitor_signals(jump)

	panel.accept()

	# In the black between the systems, Level 2's loading screen waits for Start.
	var start := SceneFlow.find_child("StartButton", true, false) as Button
	var shown := await PauseProofWait.for_condition(
		func() -> bool: return start.is_visible_in_tree() and get_tree().paused, 20000
	)
	assert_bool(shown).override_failure_message("Level 2's loading screen never showed").is_true()
	if is_failure():
		return
	var star_map := runner.find_child("StarMap") as StarMap
	var lyra := runner.find_child("Lyra") as StarSystem
	assert_object(star_map.get_current()).is_not_same(lyra)
	start.pressed.emit()

	await assert_signal(jump).wait_until(10000).is_emitted("finished", [lyra])
	assert_object(star_map.get_current()).is_same(lyra)
	assert_array(cabin.get_passengers()).not_contains([passenger])
	assert_bool(boss.is_ringing()).is_false()


func test_a_promotion_leaves_the_goals_on_the_panel_until_the_next_ones_come() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var progression := runner.find_child("Progression") as Progression
	var goals := runner.find_child("Goals") as GoalTracker
	var panel := runner.find_child("GoalPanel") as GoalPanel
	var star_map := runner.find_child("StarMap") as StarMap
	progression.start()
	var taken := goals.get_goals()
	assert_int(taken.size()).is_equal(2)
	(runner.scene() as SolarSystem).get_ledger().rate(5.0)
	for i: int in 20:
		(taken[0] as DeliveryCountGoal).passenger_delivered(null)
	await runner.simulate_frames(2)
	assert_bool(panel.visible).override_failure_message("not shown before").is_true()

	progression.promote()
	await runner.simulate_frames(2)

	assert_array(goals.get_goals()).is_equal(taken)
	assert_bool(goals.are_all_met()).is_true()
	assert_bool(panel.visible).override_failure_message("the panel went").is_true()
	assert_bool(star_map.get_jump_target() != null).is_true()

	(runner.find_child("SystemJump") as SystemJump).finished.emit(star_map.get_jump_target())
	await runner.simulate_frames(2)

	var next := goals.get_goals()
	assert_int(next.size()).is_equal(2)
	assert_bool(next[0] in taken).is_false()
	assert_bool(goals.frozen).is_false()
	assert_bool(goals.are_all_met()).is_false()
	assert_bool(panel.visible).is_true()
