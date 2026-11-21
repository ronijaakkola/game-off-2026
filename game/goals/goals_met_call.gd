class_name GoalsMetCall
extends Node
## The end of the run's goals: once every goal in [member goals] has been met for
## [constant DELAY] seconds of play, The Boss calls with the next job. The call notice's
## Answer opens their transmission; left unanswered for [constant ANSWER_SECONDS] seconds
## while it shows, it opens by itself, and The Boss starts by telling the player off.
## Either answer shows a notice that the next level isn't there yet. While a passenger's
## call rings, The Boss waits for it to end, and nobody else calls while The Boss's call
## rings. It calls once while the scene runs, so a continued run calls again.

## The player closed The Boss's transmission.
signal ended

## Seconds of play every goal holds before The Boss calls. A goal dropping back resets it.
const DELAY := 5.0
## Seconds of play the call notice shows, unanswered, before the transmission opens by itself.
const ANSWER_SECONDS := 10.0
const CALLER := "Your Boss"
## The job's offer, which ends what The Boss says: [constant TEXT] when the player answered,
## and [constant UNANSWERED_TEXT] when the call opened by itself.
const OFFER := (
	"Most of you don't get this far, but maybe I have a use for you after all. There's more "
	+ "[money]money[/money] to be made in another system, and I want you there immediately. "
	+ "I'll send you the coordinates."
)
const TEXT := "What, really? You did it? " + OFFER
const UNANSWERED_TEXT := "Number one rule: when I call, you [shout]pick[/shout] up. " + OFFER
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
# Seconds of play the call notice has shown unanswered.
var _ringing_seconds := 0.0
# Whether the quest giver had calls on before The Boss's call held them.
var _quests_were_enabled := false


func _ready() -> void:
	DebugPanel.add_button("Goals met call", _debug_ring, self)


func _process(delta: float) -> void:
	if _notice:
		# Only while the player can see it: not while the notices are hidden behind a panel.
		if _notice.is_visible_in_tree():
			_ringing_seconds += delta
		if _ringing_seconds >= ANSWER_SECONDS:
			_notice.dismiss()
			_open(UNANSWERED_TEXT)
		return
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
	_quests_were_enabled = quest_giver and quest_giver.enabled
	if quest_giver:
		quest_giver.enabled = false
	_ringing_seconds = 0.0
	_notice = notices.announce_transmission(_boss())
	_notice.action_pressed.connect(_open.bind(TEXT))


# The Boss's transmission opens, saying [param text], answered or by itself.
func _open(text: String) -> void:
	_notice = null
	var call := _boss()
	call.text = text
	# Left ringing, The Boss opens annoyed: the voice's annoyed stinger.
	if text == UNANSWERED_TEXT:
		call.mood = Passenger.Mood.ANNOYED
	call.decline_text = ANSWERS[0]
	call.accept_text = ANSWERS[1]
	call.answers_alike = true
	transmission_panel.open(call)
	await transmission_panel.answered
	if quest_giver:
		quest_giver.enabled = _quests_were_enabled
	notices.push(NEXT_LEVEL_MISSING, Notice.Kind.INFO, true)
	ended.emit()


# The Boss, as they call.
func _boss() -> Transmission:
	var call := Transmission.from_boss()
	call.caller_name = CALLER
	return call


func _debug_ring() -> void:
	ring()
