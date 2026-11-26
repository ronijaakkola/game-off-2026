class_name MidpointSlider
extends HSlider
## A slider with a notch at the middle of its range, which a drag or a click catches on: a
## value the pointer puts within [constant SNAP] of the middle lands on it. The keys and the
## wheel step past it freely, so every value can still be set. The notch is the slider's own
## middle tick.

## How near the middle a drag or a click lands on it, as a share of the range.
const SNAP := 0.035

var _pointing := false


# Runs before the slider takes the press, so the value the press sets already snaps.
func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_pointing = button.pressed


# Runs before value_changed is emitted, so listeners only hear the snapped value.
func _value_changed(new_value: float) -> void:
	if not _pointing:
		return
	var middle := (min_value + max_value) / 2.0
	if new_value != middle and absf(new_value - middle) <= SNAP * (max_value - min_value):
		value = middle
