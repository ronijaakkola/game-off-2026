class_name StargateRow
extends SlideSlot
## The station's "Travel between stars" service, at the planet the [Stargate] floats
## beside: a star on a tile and a button, as the station's other services are. It takes no
## room until [method open], which grows it into the dock panel while the player watches.
## Under another service's row it keeps [member gap] from it, as those rows do from each
## other; first in the column, it has none.

## The player pressed the button.
signal pressed

## The room between it and a service's row above it, in pixels: none while it is the
## first row. The dock panel sets it.
var gap := 0:
	set(value):
		gap = value
		(%Pad as MarginContainer).add_theme_constant_override(&"margin_top", value)


## The row, its icon and button, for a guide card to point at.
func get_row() -> Control:
	return %Row


func _on_button_pressed() -> void:
	pressed.emit()
