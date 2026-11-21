class_name FirstShiftCall
extends Node
## The start of a new run, once the tutorial's zoom out is over or, without the tutorial,
## once the scene has faded in: only the bus bars and the notices show, and The Boss calls
## to welcome the player to their first shift. Until the player closes the transmission, the
## call notice's Answer is the one thing they can do: no clicks on the map or the bus bars,
## no route changes, no pan or zoom. Left unanswered for [constant ANSWER_SECONDS] seconds of
## play while it shows, it opens by itself, and The Boss starts by telling the player off.
## Once it closes, the other panels come in, and a feature hint points at the goal panel.
## Only a new run the main menu started has it; any other run gets the HUD back at once.

## Seconds after the screen has faded in, or the bus bars have come back, before The Boss
## calls.
const DELAY := 0.8
## Seconds of play the call notice shows, unanswered, before the transmission opens by itself.
const ANSWER_SECONDS := 5.0
const CALLER := "Your Boss"
## What follows how The Boss opens: [constant TEXT] when the player answered, and
## [constant UNANSWERED_TEXT] when the call opened by itself.
const WELCOME := (
	"At Redshift Transit, we track your performance every millisecond. Good employees get "
	+ "rewarded with a [money]promotion[/money]. Do not disappoint us."
)
const TEXT := "Welcome to your first shift, resource. " + WELCOME
const UNANSWERED_TEXT := "Do not test me, resource. [shout]Answer the call.[/shout] " + WELCOME
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


func _ready() -> void:
	set_process(false)
	DebugPanel.add_button("First shift call", _ring, self)


func _process(delta: float) -> void:
	# Only while the player can see it: not while the notices are hidden behind a panel.
	if _notice.is_visible_in_tree():
		_ringing_seconds += delta
	if _ringing_seconds >= ANSWER_SECONDS:
		_notice.dismiss()
		_open(UNANSWERED_TEXT)


## Starts the run's first shift: in a new run, The Boss calls with only the bus bars
## showing; in any other, the HUD comes back at once.
func play() -> void:
	if not saver.is_new_run():
		hud.reveal_all()
		return
	hud.hide_panels()
	_hold(true)
	await hud.reveal_bars()
	while SceneFlow.is_busy():
		await get_tree().process_frame
	await get_tree().create_timer(DELAY).timeout
	_ring()


func _ring() -> void:
	if _notice:
		return
	_ringing_seconds = 0.0
	_notice = notices.announce_transmission(_boss())
	_notice.action_pressed.connect(_open.bind(TEXT))
	set_process(true)


# The Boss's transmission opens, saying [param text], answered or by itself. Once it
# closes, the HUD comes back and the goal panel's hint opens.
func _open(text: String) -> void:
	set_process(false)
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
	_hold(false)
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
