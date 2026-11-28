class_name ResearchNudge
extends Panel
## The thin outline on the dock panel's Research button while there is an upgrade to pay
## for that the player hasn't seen on the research screen ([member nudging]): in the
## Frameshift key's yellow, fainter than the key's and pulsing in step with it, and holding
## still under Reduce motion.

## Its opacity swings between these.
const DIM := 0.15
const BRIGHT := 0.6

## Whether the outline shows.
var nudging := false:
	set(value):
		nudging = value
		visible = value
		set_process(value)


func _ready() -> void:
	set_process(nudging)


func _process(_delta: float) -> void:
	var pulse := 1.0
	if not Settings.reduce_motion:
		var seconds := Time.get_ticks_msec() / 1000.0
		pulse = 0.5 - 0.5 * cos(seconds * TAU / FrameshiftKey.PULSE_SECONDS)
	self_modulate.a = lerpf(DIM, BRIGHT, pulse)
