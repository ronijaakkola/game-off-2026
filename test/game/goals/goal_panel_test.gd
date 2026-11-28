extends GdUnitTestSuite
## The goal panel: "To get promoted" and a row for each goal, with its text, how far
## along it is, and a tick once it is met.

const PANEL := "res://game/goals/goal_panel.tscn"
const CIRCLE_CHECK := preload("res://shared/icons/circle_check.svg")
## Milliseconds for a row to come in or go, with room to spare.
const SETTLE_MS := 700


func test_the_preview_shows_the_designed_goals() -> void:
	var runner := scene_runner("res://test/previews/goal_panel_preview.tscn")
	await runner.simulate_frames(5)
	# The preview's goals replace the scene's while the panel shows, so they come in.
	await await_millis(SETTLE_MS)
	var rows := _rows(runner.find_child("GoalPanel"))

	assert_int(rows.size()).is_equal(2)
	assert_str(_text(rows[0])).is_equal("Deliver 50 passengers")
	assert_str(_value(rows[0])).is_equal("12/50")
	assert_bool(_is_ticked(rows[0])).is_false()
	assert_str(_text(rows[1])).is_equal("Maintain 4.0 rating")
	assert_str(_value(rows[1])).is_equal("4.2")
	assert_bool(_is_ticked(rows[1])).is_true()


# The target mark sticks out over and under the bar, and the bar sits at the bottom of the
# goals: nothing the panel clips to may cut it off.
func test_the_rating_goals_target_mark_shows_whole() -> void:
	var runner := scene_runner("res://test/previews/goal_panel_preview.tscn")
	await runner.simulate_frames(5)
	# The preview's goals replace the scene's while the panel shows, so they come in.
	await await_millis(SETTLE_MS)
	var panel := runner.find_child("GoalPanel") as Control
	var marker := _rows(panel)[1].find_child("Marker") as Control
	assert_bool(marker.visible).is_true()

	var mark := marker.get_global_rect()
	var parent := marker.get_parent_control()
	while parent:
		if parent.clip_contents:
			(
				assert_bool(parent.get_global_rect().encloses(mark))
				. override_failure_message("%s cuts off the mark at %s" % [parent.name, mark])
				. is_true()
			)
		parent = parent.get_parent_control()


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
	await await_millis(SETTLE_MS)
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
		# A row whose goal has gone stays a moment while it leaves.
		var slot := row.get_parent() as SlideSlot
		if not row.is_queued_for_deletion() and (not slot or slot.is_open()):
			rows.append(row as GoalRow)
	return rows


func _text(row: GoalRow) -> String:
	return (row.find_child("TextLabel", true, false) as Label).text


func _value(row: GoalRow) -> String:
	return (row.find_child("ValueLabel", true, false) as Label).text


func _is_ticked(row: GoalRow) -> bool:
	return (row.find_child("Icon", true, false) as TextureRect).texture == CIRCLE_CHECK
