class_name FirstShiftCall
extends Node
## The Boss's calls that open play with only the bus bars showing: at the start of a new
## run, once the tutorial's zoom out is over or, without the tutorial, once the scene has
## faded in, to welcome the player to their first shift; and as the bus arrives in a star
## system after a jump, with what that system says ([member StarSystem.arrival_call]).
## Until the player closes the transmission, the call notice's Answer is the one thing they
## can do: no clicks on the map or the bus bars, no route changes, no pan or zoom. Left
## unanswered for [constant ANSWER_SECONDS] seconds of play while it shows, it opens by
## itself, and The Boss starts by telling the player off. Once it closes, the other panels
## come in, and a feature hint points at the goal panel ([signal closed]).
## Only a new run the main menu started has the first-shift call; any other run gets the
## HUD back at once.

## The call closed and the HUD is coming back.
signal closed

## Seconds after the screen has faded in, or the bus bars have come back, before The Boss
## calls.
const DELAY := 0.8
## Seconds of play the call notice shows, unanswered, before the transmission opens by itself.
const ANSWER_SECONDS := 5.0
const CALLER := "Your Boss"
## The debug panel's group for the calls, transmissions, quests and notices.
const DEBUG_GROUP := "Calls"
## What The Boss says on the first shift, after how they open: [constant OPENING] when the
## player answered, and [constant UNANSWERED_OPENING] when the call opened by itself, as
## every call of theirs here does.
const WELCOME := (
	"At Redshift Transit, we track your performance every millisecond. Good employees get "
	+ "rewarded with a [money]promotion[/money]. Do not disappoint us."
)
const OPENING := "Welcome to your first shift, resource. "
const UNANSWERED_OPENING := "Do not test me, resource. [shout]Answer the call.[/shout] "
## The two answers, which mean the same.
const ANSWERS: Array[String] = ["Sure boss", "I'll do my best"]

@export var hud: HudLayout
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Says whether this is a new run.
@export var saver: GameSaver
## Its route holds while The Boss calls.
@export var bus: FrameshiftBus
## Holds still while The Boss calls.
@export var rig: CameraRig
## Points at the goal panel once the call is over.
@export var hints: FeatureHints
@export var goal_panel: Control

var _notice: Notice
# Seconds of play the call notice has shown unanswered.
var _ringing_seconds := 0.0
# What The Boss says after how they open, on the call ringing.
var _text := ""
# Counts the calls asked for, so one asked for while another waits to ring replaces it.
var _asked := 0


func _ready() -> void:
	set_process(false)
	DebugPanel.add_button("First shift call", _ring.bind(WELCOME, OPENING), self, DEBUG_GROUP)


func _process(delta: float) -> void:
	# Only while the player can see it: not while the notices are hidden behind a panel.
	if _notice.is_visible_in_tree():
		_ringing_seconds += delta
	if _ringing_seconds >= ANSWER_SECONDS:
		_notice.dismiss()
		_open(UNANSWERED_OPENING)


## Starts the run's first shift: in a new run, The Boss calls with only the bus bars
## showing; in any other, the HUD comes back at once.
func play() -> void:
	if not saver.is_new_run():
		hud.reveal_all()
		return
	var asked := _ask()
	hud.hide_panels()
	_hold(true)
	await hud.reveal_bars()
	while SceneFlow.is_busy():
		await get_tree().process_frame
	await get_tree().create_timer(DELAY).timeout
	if asked == _asked:
		_ring(WELCOME, OPENING)


## The bus has jumped into [param system], with the HUD out: The Boss calls with what the
## system says, with only the bus bars showing. A system that says nothing gets the HUD
## back at once.
func arrive(system: StarSystem) -> void:
	var asked := _ask()
	if system.arrival_call.is_empty():
		hud.reveal_all()
		closed.emit()
		return
	hud.hide_panels()
	_hold(true)
	await hud.reveal_bars()
	await get_tree().create_timer(DELAY).timeout
	if asked == _asked:
		_ring(system.arrival_call)


## Drops a call waiting to ring or ringing, and lets the route and the camera go, as the
## bus jumps on.
func cancel() -> void:
	_ask()
	_hold(false)


# A new call is asked for: one still waiting to ring, or ringing, goes.
func _ask() -> int:
	_asked += 1
	set_process(false)
	if _notice:
		_notice.dismiss()
		_notice = null
	return _asked


# The Boss's call rings, to say [param text] after [param opening] once answered.
func _ring(text: String, opening := "") -> void:
	if _notice:
		return
	_text = text
	_ringing_seconds = 0.0
	_notice = notices.announce_transmission(_boss())
	_notice.action_pressed.connect(_open.bind(opening))
	set_process(true)


# The Boss's transmission opens, answered or by itself, with [param opening] before what
# they say. Once it closes, the HUD comes back and the goal panel's hint opens.
func _open(opening: String) -> void:
	set_process(false)
	_notice = null
	var call := _boss()
	call.text = opening + _text
	# Left ringing, The Boss opens annoyed: the voice's annoyed stinger.
	if opening == UNANSWERED_OPENING:
		call.mood = Passenger.Mood.ANNOYED
	call.decline_text = ANSWERS[0]
	call.accept_text = ANSWERS[1]
	call.answers_alike = true
	transmission_panel.open(call)
	await transmission_panel.answered
	_hold(false)
	closed.emit()
	await hud.reveal_all()
	hints.offer(&"goals", goal_panel)


# Holds the route and the camera while The Boss calls, or lets them go.
func _hold(held: bool) -> void:
	bus.route_locked = held
	rig.locked = held


# The Boss, as they call.
func _boss() -> Transmission:
	var call := Transmission.from_boss()
	call.caller_name = CALLER
	return call
