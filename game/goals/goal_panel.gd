class_name GoalPanel
extends PanelContainer
## The player's goals, in the top right corner over the dock panel: "To get promotion"
## and a row for each goal the [member tracker] has, in the order added. Under a thin line
## and a flag, "Quests" and a row for each quest the [member quest_giver] shows, the one
## under way and those just finished. Each part shows only while it has rows, the line
## only between the two, and the panel only while there are any.

const ROW := preload("res://game/goals/goal_row.tscn")
const QUEST_ROW := preload("res://game/quests/quest_row.tscn")

## The goals a promotion takes.
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
## Whose quests show.
@export var quest_giver: QuestGiver:
	set(value):
		if quest_giver:
			quest_giver.quest_added.disconnect(_on_quest_added)
			quest_giver.quest_removed.disconnect(_on_quest_removed)
		quest_giver = value
		if quest_giver:
			quest_giver.quest_added.connect(_on_quest_added)
			quest_giver.quest_removed.connect(_on_quest_removed)
		if is_node_ready():
			_sync_rows()
## Where the quests' passengers' portraits are rendered.
@export var portrait_studio: PortraitStudio

var _rows: Dictionary[Goal, GoalRow] = {}
var _quest_rows: Dictionary[Quest, QuestRow] = {}


func _ready() -> void:
	_sync_rows()


func _sync_rows() -> void:
	for row: Node in _rows.values() + _quest_rows.values():
		row.queue_free()
	_rows.clear()
	_quest_rows.clear()
	if tracker:
		for goal: Goal in tracker.get_goals():
			_on_goal_added(goal)
	if quest_giver:
		for quest: Quest in quest_giver.get_quests():
			_on_quest_added(quest)
	_show_parts()


func _on_goal_added(goal: Goal) -> void:
	var row := ROW.instantiate() as GoalRow
	row.goal = goal
	(%GoalRows as Container).add_child(row)
	_rows[goal] = row
	_show_parts()


func _on_goal_removed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.queue_free()
		_rows.erase(goal)
	_show_parts()


func _on_goal_changed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.refresh()


func _on_quest_added(quest: Quest) -> void:
	var row := QUEST_ROW.instantiate() as QuestRow
	row.studio = portrait_studio
	row.quest = quest
	(%QuestRows as Container).add_child(row)
	_quest_rows[quest] = row
	_show_parts()


func _on_quest_removed(quest: Quest) -> void:
	var row: QuestRow = _quest_rows.get(quest)
	if row:
		row.queue_free()
		_quest_rows.erase(quest)
	_show_parts()


func _show_parts() -> void:
	var promotion := not _rows.is_empty()
	var asked := not _quest_rows.is_empty()
	(%Goals as Control).visible = promotion
	(%Quests as Control).visible = asked
	(%Divider as Control).visible = promotion and asked
	visible = promotion or asked
