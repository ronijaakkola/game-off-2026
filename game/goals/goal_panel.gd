class_name GoalPanel
extends PanelContainer
## The player's goals, in the top right corner over the dock panel: "To get promoted"
## and a row for each goal the [member tracker] has, in the order added. Under a thin line
## and a flag, "Quests" and a row for each quest the [member quest_giver] shows, the one
## under way and those just finished. Each part shows only while it has rows, the line
## only between the two, and the panel only while there are any.
## The quests come in and go as the notices do ([SlideSlot]): the panel grows to make room
## while the part rises in and fades, and a quest that goes fades out before the panel
## closes over it. The first quest brings the whole part in, heading and all, and the last
## takes it out. What is already there when the panel is first shown doesn't move.

const ROW := preload("res://game/goals/goal_row.tscn")
const QUEST_ROW := preload("res://game/goals/quest_row.tscn")
## Pixels between the promotion goals and the quests' part.
const PART_GAP := 8

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
# Each quest's row sits in a slot of its own.
var _quest_slots: Dictionary[Quest, SlideSlot] = {}


func _ready() -> void:
	(%QuestSlot as SlideSlot).closed.connect(_show_parts)
	_sync_rows()


func _sync_rows() -> void:
	for row: Node in _rows.values() + _quest_slots.values():
		row.queue_free()
	_rows.clear()
	_quest_slots.clear()
	if tracker:
		for goal: Goal in tracker.get_goals():
			_on_goal_added(goal)
	if quest_giver:
		for quest: Quest in quest_giver.get_quests():
			_add_quest(quest, false)
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
	_add_quest(quest, true)


# Adds a row for [param quest] in a slot of its own. The first row brings the whole part
# in; a later one opens its own slot.
func _add_quest(quest: Quest, animated: bool) -> void:
	var row := QUEST_ROW.instantiate() as QuestRow
	row.studio = portrait_studio
	row.quest = quest
	var slot := SlideSlot.new()
	slot.add_child(row)
	(%QuestRows as Container).add_child(slot)
	_quest_slots[quest] = slot
	var part := %QuestSlot as SlideSlot
	_show_parts()
	slot.open(animated and part.is_open())
	part.open(animated and is_visible_in_tree())


# The last row takes the whole part out with it; any other closes its own slot.
func _on_quest_removed(quest: Quest) -> void:
	var slot: SlideSlot = _quest_slots.get(quest)
	if not slot:
		return
	_quest_slots.erase(quest)
	var part := %QuestSlot as SlideSlot
	if _quest_slots.is_empty():
		part.closed.connect(slot.queue_free, CONNECT_ONE_SHOT)
		part.close()
	else:
		slot.closed.connect(slot.queue_free, CONNECT_ONE_SHOT)
		slot.close()


# The quests' part stays until it has closed, so the panel doesn't go while it leaves.
func _show_parts() -> void:
	var promotion := not _rows.is_empty()
	var asked := not _quest_slots.is_empty() or (%QuestSlot as SlideSlot).visible
	(%Goals as Control).visible = promotion
	(%Divider as Control).visible = promotion
	(%Section as MarginContainer).add_theme_constant_override(
		&"margin_top", PART_GAP if promotion else 0
	)
	visible = promotion or asked
