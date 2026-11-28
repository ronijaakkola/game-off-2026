class_name StargateRow
extends SlideSlot
## The station's "Travel between stars" service, at the planet the [Stargate] floats
## beside: a star on a tile and a button, as the station's other services are. It takes no
## room until [method open], which grows it into the dock panel while the player watches.

## The player pressed the button.
signal pressed


## The row, its icon and button, for a guide card to point at.
func get_row() -> Control:
	return %Row


func _on_button_pressed() -> void:
	pressed.emit()
