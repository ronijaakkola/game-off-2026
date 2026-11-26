class_name TitleCard
extends Control
## The main menu's title card on the web, where audio starts only after the player clicks or
## presses a key in the game. It takes over from the loading page and the boot splash, which
## show the logo at the same size and place on the same navy: the navy fades to the menu's
## background, panned to its empty right half, and "Click to start" fades in under the logo
## and breathes. A click, a tap or a key, other than Esc, which the browser doesn't count,
## starts it: the logo and the prompt fade out, and the menu comes in. Under Reduce motion
## the prompt holds still.

## The player clicked, tapped or pressed a key: the browser lets audio play from now on.
signal started

## Seconds the navy takes to fade to the menu's background.
const COVER_SECONDS := 0.8
## Seconds after the title card shows that the prompt starts to fade in, and how long it takes.
const PROMPT_DELAY := 0.5
const PROMPT_SECONDS := 0.5
## Seconds of one breath of the prompt, and how faint it gets.
const BREATH_SECONDS := 2.0
const BREATH_ALPHA := 0.55
## Seconds the logo and the prompt take to fade once the player starts.
const LEAVE_SECONDS := 0.2

var _motion: Tween
var _breath: Tween
var _started := false


## Shows the title card over the menu, from the navy the loading page ends on.
func open() -> void:
	show()
	%Cover.modulate.a = 1.0
	%Prompt.modulate.a = 0.0
	_motion = create_tween().set_parallel()
	_motion.tween_property(%Cover, ^"modulate:a", 0.0, COVER_SECONDS).set_trans(Tween.TRANS_SINE)
	_motion.tween_property(%Prompt, ^"modulate:a", 1.0, PROMPT_SECONDS).set_delay(PROMPT_DELAY)
	if not Settings.reduce_motion:
		_motion.tween_callback(_breathe).set_delay(PROMPT_DELAY + PROMPT_SECONDS)


## Fades the logo and the prompt out, then hides. Returns the seconds it takes.
func leave() -> float:
	for tween: Tween in [_motion, _breath]:
		if tween:
			tween.kill()
	_motion = create_tween().set_parallel()
	for faded: Control in [%Cover, %Prompt, %Logo]:
		_motion.tween_property(faded, ^"modulate:a", 0.0, LEAVE_SECONDS)
	_motion.tween_callback(hide).set_delay(LEAVE_SECONDS)
	return LEAVE_SECONDS


func _breathe() -> void:
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_breath.tween_property(%Prompt, ^"modulate:a", BREATH_ALPHA, BREATH_SECONDS / 2.0)
	_breath.tween_property(%Prompt, ^"modulate:a", 1.0, BREATH_SECONDS / 2.0)


func _gui_input(event: InputEvent) -> void:
	if _starts(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and _starts(event):
		get_viewport().set_input_as_handled()


# Whether [param event] starts the game, once: what the browser counts as the player's
# go-ahead for audio. A wheel turn doesn't count, nor a touch until it lifts, so a mouse
# press made up from a touch is left to the touch.
func _starts(event: InputEvent) -> bool:
	if _started or not _counts(event):
		return false
	_started = true
	started.emit()
	return true


static func _counts(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	if mouse:
		return (
			mouse.pressed
			and mouse.device != InputEvent.DEVICE_ID_EMULATION
			and mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
		)
	var touch := event as InputEventScreenTouch
	if touch:
		return not touch.pressed
	var key := event as InputEventKey
	if key:
		return key.pressed and not key.echo and key.keycode != KEY_ESCAPE
	return false
