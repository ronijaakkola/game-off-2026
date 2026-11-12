class_name GoalPanel
extends PanelContainer
## The player's goals, in the top right corner over the dock panel: "To get promotion"
## and a row for each goal the [member tracker] has, in the order added, then "Quests" and
## a row for each quest [member quests] has. A heading shows only while it has rows, and
## the panel only while there are any.

const ROW := preload("res://game/goals/goal_row.tscn")

## The goals a promotion takes.
@export var tracker: GoalTracker:
	set(value):
		_unfollow(tracker)
		tracker = value
		_follow(tracker)
		if is_node_ready():
			_sync_rows()
## The quests under way, and those just finished.
@export var quests: GoalTracker:
	set(value):
		_unfollow(quests)
		quests = value
		_follow(quests)
		if is_node_ready():
			_sync_rows()

var _rows: Dictionary[Goal, GoalRow] = {}


func _ready() -> void:
	_sync_rows()


func _follow(goals: GoalTracker) -> void:
	if goals:
		goals.goal_added.connect(_on_goal_added.bind(goals))
		goals.goal_removed.connect(_on_goal_removed)
		goals.goal_changed.connect(_on_goal_changed)


func _unfollow(goals: GoalTracker) -> void:
	if goals:
		goals.goal_added.disconnect(_on_goal_added.bind(goals))
		goals.goal_removed.disconnect(_on_goal_removed)
		goals.goal_changed.disconnect(_on_goal_changed)


func _sync_rows() -> void:
	for row: GoalRow in _rows.values():
		row.queue_free()
	_rows.clear()
	for goals: GoalTracker in [tracker, quests]:
		if goals:
			for goal: Goal in goals.get_goals():
				_on_goal_added(goal, goals)
	_show_headers()


# A promotion goal's row goes above the "Quests" heading, a quest's at the bottom.
func _on_goal_added(goal: Goal, goals: GoalTracker) -> void:
	var row := ROW.instantiate() as GoalRow
	row.goal = goal
	var rows := %Rows as Container
	rows.add_child(row)
	if goals == tracker:
		rows.move_child(row, (%QuestHeader as Control).get_index())
	_rows[goal] = row
	_show_headers()


func _on_goal_removed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.queue_free()
		_rows.erase(goal)
	_show_headers()


func _on_goal_changed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.refresh()


func _show_headers() -> void:
	var promotion := tracker and not tracker.get_goals().is_empty()
	var asked := quests and not quests.get_goals().is_empty()
	(%Header as Control).visible = promotion
	(%QuestHeader as Control).visible = asked
	visible = promotion or asked
