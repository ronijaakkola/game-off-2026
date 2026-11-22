extends GdUnitTestSuite
## A promotion in the real scene: the goals it took stay on the goal panel, ticked, until
## the bus has jumped and the next system's goals replace them.

const SCENE := "res://game/solar_system/solar_system.tscn"


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
