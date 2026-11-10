class_name GoalPanel
extends PanelContainer
## The player's goals, in the top right corner over the dock panel: "To get promotion"
## and a row for each goal the [member tracker] has, in the order added. Hidden while
## there are none.

const ROW := preload("res://game/goals/goal_row.tscn")

## The goals shown.
@export var tracker: GoalTracker:
	set(value):
		if tracker:
			tracker.goal_added.disconnect(_on_goal_added)
			tracker.goal_removed.disconnect(_on_goal_removed)
			tracker.goal_changed.disconnect(_on_goal_changed)
		tracker = value
		if tracker:
			tracker.goal_added.connect(_on_goal_added)
			tracker.goal_removed.connect(_on_goal_removed)
			tracker.goal_changed.connect(_on_goal_changed)
		if is_node_ready():
			_sync_rows()

var _rows: Dictionary[Goal, GoalRow] = {}


func _ready() -> void:
	_sync_rows()


func _sync_rows() -> void:
	for row: GoalRow in _rows.values():
		row.queue_free()
	_rows.clear()
	if tracker:
		for goal: Goal in tracker.get_goals():
			_on_goal_added(goal)
	visible = not _rows.is_empty()


func _on_goal_added(goal: Goal) -> void:
	var row := ROW.instantiate() as GoalRow
	row.goal = goal
	(%Rows as Container).add_child(row)
	_rows[goal] = row
	visible = true


func _on_goal_removed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.queue_free()
		_rows.erase(goal)
	visible = not _rows.is_empty()


func _on_goal_changed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.refresh()
