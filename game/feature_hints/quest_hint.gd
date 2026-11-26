extends Node
## Offers the quests feature hint the first time the player takes on a quest: on the goal
## panel's quests, heading and row, [constant SETTLE_SECONDS] after the quest is taken on,
## so the card opens on a row that has slid in and stopped moving.

## Seconds from a quest being taken on to the hint: time for its row to slide into the
## panel, and a beat.
const SETTLE_SECONDS := SlideSlot.GAP_SECONDS + SlideSlot.ENTER_SECONDS + 0.3

@export var hints: FeatureHints
@export var quest_giver: QuestGiver
@export var goal_panel: GoalPanel

# Seconds until the hint is offered.
var _until_hint := 0.0


func _ready() -> void:
	set_process(false)
	quest_giver.quest_added.connect(_on_quest_added)
	hints.set_debug_target(&"quests", goal_panel.get_quests_part)


func _process(delta: float) -> void:
	_until_hint -= delta
	if _until_hint > 0.0:
		return
	set_process(false)
	if hints.offer(&"quests", goal_panel.get_quests_part()):
		quest_giver.quest_added.disconnect(_on_quest_added)


func _on_quest_added(_quest: Quest) -> void:
	_until_hint = SETTLE_SECONDS
	set_process(true)
