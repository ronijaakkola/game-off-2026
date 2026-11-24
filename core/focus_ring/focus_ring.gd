extends Node
## The focus ring shows only to a player using the keys. Godot already hides it when a click
## or a touch gives a control focus; [method grab] does the same for focus given in code, as
## a menu does when it opens, so the ring shows only if the last press was a key or a
## gamepad button. The first arrow key or Tab press shows it wherever the focus is.

# Whether the last press was the pointer's: a mouse button or a touch. True at the start,
# so nothing shows a ring before the player has touched the keys.
var _pointer_last := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_pointer_last = true
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
		_pointer_last = false


## Gives [param control] focus, with its ring showing only if the last press was a key.
func grab(control: Control) -> void:
	control.grab_focus(_pointer_last)


## Takes the focus away if its ring is hidden. For keys that do something else too: the
## arrow keys also move the focus, which would show the ring of the button last clicked.
func drop_hidden() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner and not owner.has_focus(true):
		owner.release_focus()
