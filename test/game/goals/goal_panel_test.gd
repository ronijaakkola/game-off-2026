extends GdUnitTestSuite
## The goal panel: "To get promoted" and a row for each goal, with its text, how far
## along it is, and a tick once it is met.

const PANEL := "res://game/goals/goal_panel.tscn"
const CIRCLE_CHECK := preload("res://shared/icons/circle_check.svg")


func test_the_preview_shows_the_designed_goals() -> void:
	var runner := scene_runner("res://test/previews/goal_panel_preview.tscn")
	await runner.simulate_frames(5)
	var rows := _rows(runner.find_child("GoalPanel"))

	assert_int(rows.size()).is_equal(2)
	assert_str(_text(rows[0])).is_equal("Deliver 50 passengers")
	assert_str(_value(rows[0])).is_equal("12/50")
	assert_bool(_is_ticked(rows[0])).is_false()
	assert_str(_text(rows[1])).is_equal("Maintain 4.0 rating")
	assert_str(_value(rows[1])).is_equal("4.2")
	assert_bool(_is_ticked(rows[1])).is_true()


func test_shows_a_row_for_each_goal_added_and_hides_with_none() -> void:
	var runner := scene_runner(PANEL)
	var tracker := _tracker(runner)
	assert_bool((runner.scene() as Control).visible).is_false()

	var goal := DeliveryCountGoal.new(30)
	tracker.add(goal)
	await runner.simulate_frames(1)
	assert_bool((runner.scene() as Control).visible).is_true()
	assert_int(_rows(runner.scene()).size()).is_equal(1)

	tracker.remove(goal)
	await runner.simulate_frames(1)
	assert_bool((runner.scene() as Control).visible).is_false()
	assert_int(_rows(runner.scene()).size()).is_equal(0)


func test_a_delivery_goal_counts_up_and_ticks_once_done() -> void:
	var runner := scene_runner(PANEL)
	var goal := DeliveryCountGoal.new(2)
	_tracker(runner).add(goal)
	var row := _rows(runner.scene())[0]

	goal.passenger_delivered(null)
	assert_str(_value(row)).is_equal("1/2")
	assert_bool(_is_ticked(row)).is_false()

	goal.passenger_delivered(null)
	assert_str(_value(row)).is_equal("2/2")
	assert_bool(_is_ticked(row)).is_true()


func test_a_rating_goal_shows_a_dash_before_the_first_rating_and_unticks_below() -> void:
	var runner := scene_runner(PANEL)
	var goal := RatingGoal.new(4.0)
	_tracker(runner).add(goal)
	var row := _rows(runner.scene())[0]
	assert_str(_value(row)).is_equal("–")

	goal.rating_changed(4.5, 1)
	assert_str(_value(row)).is_equal("4.5")
	assert_bool(_is_ticked(row)).is_true()

	goal.rating_changed(3.8, 2)
	assert_str(_value(row)).is_equal("3.8")
	assert_bool(_is_ticked(row)).is_false()


func _tracker(runner: GdUnitSceneRunner) -> GoalTracker:
	var tracker := auto_free(GoalTracker.new()) as GoalTracker
	runner.scene().add_child(tracker)
	(runner.scene() as GoalPanel).tracker = tracker
	return tracker


func _rows(panel: Node) -> Array[GoalRow]:
	var rows: Array[GoalRow] = []
	for row: Node in panel.find_children("*", "GoalRow", true, false):
		if not row.is_queued_for_deletion():
			rows.append(row as GoalRow)
	return rows


func _text(row: GoalRow) -> String:
	return (row.find_child("TextLabel", true, false) as Label).text


func _value(row: GoalRow) -> String:
	return (row.find_child("ValueLabel", true, false) as Label).text


func _is_ticked(row: GoalRow) -> bool:
	return (row.find_child("Icon", true, false) as TextureRect).texture == CIRCLE_CHECK
