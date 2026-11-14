class_name TutorialCall
extends Node
## The Boss's calls in the [Tutorial]. The first opens it: the screen fades in slowly from
## black with only the bus bars showing ([method HudLayout.hide_for_call]), and once it has,
## The Boss calls ([method play]). The last closes it ([method ring]). Either way the call
## notice's Answer, the one thing the player can do, opens The Boss's transmission, and
## [signal ended] once the player closes it. [method cancel] takes the notice away, as when
## the tutorial is skipped.

## The player closed The Boss's transmission.
signal ended

## Seconds after the screen has faded in before The Boss calls.
const DELAY := 0.8
## Who calls, what The Boss says first, with the planets' names for {home} and
## {destination}, and the two answers, which both accept.
const FIRST_CALLER := "Your Boss"
const FIRST_TEXT := (
	"Finally a new human resource, what took you so long? I remind you that you are still "
	+ "on a trial period. Please sign this contract and show me that you are capable "
	+ "material. Only then we can talk business."
)
const FIRST_ANSWERS: Array[String] = ["Sure boss", "I'm ready"]
## What The Boss says last, once the player has researched, and the answers.
const LAST_CALLER := "The Boss"
const LAST_TEXT := (
	"Finally a worthy resource. You passed your trial period, and I want you to work in the "
	+ "whole star system. I'm unlocking the frameshift planet lock now. And make sure you "
	+ "will not ruin my company's good name."
)
const LAST_ANSWERS: Array[String] = ["Sure boss", "Trying my best"]

@export var hud: HudLayout
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel

var _notice: Notice
var _cancelled := false


## Fades in and calls, about the ride from [param home] to [param destination].
func play(home: Planet, destination: Planet) -> void:
	hud.hide_for_call()
	await hud.faded_in
	await get_tree().create_timer(DELAY).timeout
	var names := {"home": home.display_name, "destination": destination.display_name}
	ring(FIRST_CALLER, FIRST_TEXT.format(names), FIRST_ANSWERS)


## Calls: The Boss, as [param caller], says [param text], and the transmission's two
## buttons say [param answers], both accepting.
func ring(caller: String, text: String, answers: Array[String]) -> void:
	if _cancelled:
		return
	_notice = notices.announce_transmission()
	_notice.action_pressed.connect(_on_answered.bind(caller, text, answers))


## Takes the call notice away, and no call comes or ends after.
func cancel() -> void:
	_cancelled = true
	if _notice:
		_notice.dismiss()
		_notice = null


# Answer: The Boss's transmission opens.
func _on_answered(caller: String, text: String, answers: Array[String]) -> void:
	_notice = null
	var call := Transmission.from_boss()
	call.caller_name = caller
	call.text = text
	call.decline_text = answers[0]
	call.accept_text = answers[1]
	call.answers_alike = true
	transmission_panel.open(call)
	await transmission_panel.answered
	if not _cancelled:
		ended.emit()
