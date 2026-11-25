extends Node
## The solar system with the debug panel open, as F2 opens it, to see the main card's
## buttons and its Sections.


func _ready() -> void:
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.physical_keycode = DebugPanel.TOGGLE_KEY
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
