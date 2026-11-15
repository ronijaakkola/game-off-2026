class_name GoalsMetCall
extends Node
## The end of the run's goals: once every goal in [member goals] has been met for
## [constant DELAY] seconds of play, The Boss calls with the next job. The call notice's
## Answer opens their transmission, and either answer shows a notice that the next level
## isn't there yet. While a passenger's call rings, The Boss waits for it to end, and nobody
## else calls while The Boss's call rings. It calls once a run.

## The player closed The Boss's transmission.
signal ended

## Seconds of play every goal holds before The Boss calls. A goal dropping back resets it.
const DELAY := 5.0
const CALLER := "Your Boss"
const TEXT := (
	"What, really? You did it? Most of you don't get this far, but maybe I have a use for "
	+ "you after all. There's more money to be made in another system, and I want you there "
	+ "immediately. I'll send you the coordinates."
)
## The two answers, which mean the same.
const ANSWERS: Array[String] = ["Sure boss", "I guess I cannot refuse"]
const NEXT_LEVEL_MISSING := "The next level is not available yet."

## The goals a promotion takes.
@export var goals: GoalTracker
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Holds its calls while The Boss's call rings.
@export var quest_giver: QuestGiver

# Seconds every goal has been met, while the game runs.
var _met_seconds := 0.0
var _called := false
var _notice: Notice


func _ready() -> void:
	DebugPanel.add_button("Goals met call", _debug_ring, self)


func _process(delta: float) -> void:
	if _called or not goals:
		return
	_met_seconds = _met_seconds + delta if goals.are_all_met() else 0.0
	if _met_seconds < DELAY or (quest_giver and quest_giver.is_calling()):
		return
	ring()


## Whether The Boss has called this run.
func has_called() -> bool:
	return _called


## The Boss calls now, if they haven't yet.
func ring() -> void:
	if _called:
		return
	_called = true
	var quests_were_enabled := quest_giver and quest_giver.enabled
	if quest_giver:
		quest_giver.enabled = false
	_notice = notices.announce_transmission()
	await _notice.action_pressed
	_notice = null
	var call := Transmission.from_boss()
	call.caller_name = CALLER
	call.text = TEXT
	call.decline_text = ANSWERS[0]
	call.accept_text = ANSWERS[1]
	call.answers_alike = true
	transmission_panel.open(call)
	await transmission_panel.answered
	if quest_giver:
		quest_giver.enabled = quests_were_enabled
	notices.push(NEXT_LEVEL_MISSING, Notice.Kind.INFO, true)
	ended.emit()


func _debug_ring() -> void:
	ring()
