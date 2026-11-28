class_name BeckonPulse
extends RefCounted
## The dock panel's call for a pick-up ([member DockPanel.beckon_boarding]): a pulse that
## brightens quickly and fades slowly, again and again, and holds bright under Reduce
## motion. It glows on the card's border and hands each step's glow to the rows.

## The seconds a pulse takes to brighten, and to fade before the next.
const RISE_SECONDS := 0.3
const FADE_SECONDS := 1.0
## The card's border while beckoning: its width in pixels, its colour at the height of a
## pulse, and its opacity between pulses, as a share of that.
const BORDER := 2
const COLOR := Color(1.0, 1.0, 1.0, 0.9)
const BORDER_LOW := 0.25

var _card: Control
# Takes each step's glow, 0 to 1, for the rows.
var _on_glow: Callable
var _on := false
var _tween: Tween


func _init(card: Control, on_glow: Callable) -> void:
	_card = card
	_on_glow = on_glow


## Pulses while [param on], or puts the card back and the rows at full glow.
func play(on: bool) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_on = on
	_set_glow(1.0)
	if not on:
		_card.remove_theme_stylebox_override(&"panel")
		return
	if Settings.reduce_motion:
		return
	_tween = _card.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_set_glow, 0.0, 1.0, RISE_SECONDS)
	_tween.tween_method(_set_glow, 1.0, 0.0, FADE_SECONDS)


func _set_glow(glow: float) -> void:
	_on_glow.call(glow)
	if not _on:
		return
	_card.remove_theme_stylebox_override(&"panel")
	var style := _card.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if not style:
		return
	style.set_border_width_all(BORDER)
	style.border_color = COLOR
	style.border_color.a *= lerpf(BORDER_LOW, 1.0, glow)
	_card.add_theme_stylebox_override(&"panel", style)
