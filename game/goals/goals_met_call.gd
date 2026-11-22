class_name GoalsMetCall
extends Node
## The Boss's call with the promotion, which [method ring] starts once every goal holds.
## The call notice's Answer opens their transmission; left unanswered for
## [constant ANSWER_SECONDS] seconds while it shows, it opens by itself, and The Boss starts
## by telling the player off. Its one answer takes the promotion: "Jump to new system", or,
## in the last system, an answer to every system joining. Nobody else calls while it rings.

## The player answered The Boss: the promotion goes ahead.
signal answered

## Seconds of play the call notice shows, unanswered, before the transmission opens by itself.
const ANSWER_SECONDS := 10.0
const CALLER := "Your Boss"
## The offer, which ends what The Boss says: after [constant TEXT] when the player answered,
## and after [constant UNANSWERED_TEXT] when the call opened by itself. [constant OFFER]
## sends the bus to the next system, and [constant JOIN_OFFER], in the last one, joins them.
const OFFER := (
	"Most of you don't get this far, but maybe I have a use for you after all. There's more "
	+ "[money]money[/money] to be made in another system, and I want you there immediately. "
	+ "Anyone still on your bus can find their own way."
)
const JOIN_OFFER := (
	"You've worked every system I have. From now on they're all your route, and so is all "
	+ "the [money]money[/money] in them."
)
const TEXT := "What, really? You did it? "
const UNANSWERED_TEXT := "Number one rule: when I call, you [shout]pick[/shout] up. "
## The answer that jumps, and the one that joins every system.
const JUMP_ANSWER := "Jump to new system"
const JOIN_ANSWER := "Sure boss"

@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Holds its calls while The Boss's call rings.
@export var quest_giver: QuestGiver

var _ringing := false
var _joins := false
var _notice: Notice
# Seconds of play the call notice has shown unanswered.
var _ringing_seconds := 0.0
# Whether the quest giver had calls on before The Boss's call held them.
var _quests_were_enabled := false


func _process(delta: float) -> void:
	if not _notice:
		return
	# Only while the player can see it: not while the notices are hidden behind a panel.
	if _notice.is_visible_in_tree():
		_ringing_seconds += delta
	if _ringing_seconds >= ANSWER_SECONDS:
		_notice.dismiss()
		_open(UNANSWERED_TEXT)


## Whether The Boss's call is ringing or open, until the player answers it.
func is_ringing() -> bool:
	return _ringing


## The Boss calls with the promotion, unless they already are: with [param joins] the one
## in the last system, which joins every system, else the one that jumps to the next.
func ring(joins: bool) -> void:
	if _ringing:
		return
	_ringing = true
	_joins = joins
	_quests_were_enabled = quest_giver and quest_giver.enabled
	if quest_giver:
		quest_giver.enabled = false
	_ringing_seconds = 0.0
	_notice = notices.announce_transmission(_boss())
	_notice.action_pressed.connect(_open.bind(TEXT))


# The Boss's transmission opens, starting with [param opening], answered or by itself.
func _open(opening: String) -> void:
	_notice = null
	var call := _boss()
	call.text = opening + (JOIN_OFFER if _joins else OFFER)
	# Left ringing, The Boss opens annoyed: the voice's annoyed stinger.
	if opening == UNANSWERED_TEXT:
		call.mood = Passenger.Mood.ANNOYED
	call.accept_text = JOIN_ANSWER if _joins else JUMP_ANSWER
	transmission_panel.open(call)
	await transmission_panel.answered
	if quest_giver:
		quest_giver.enabled = _quests_were_enabled
	_ringing = false
	answered.emit()


# The Boss, as they call.
func _boss() -> Transmission:
	var call := Transmission.from_boss()
	call.caller_name = CALLER
	return call
