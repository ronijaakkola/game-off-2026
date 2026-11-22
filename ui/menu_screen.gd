class_name MenuScreen
extends Control
## A screen a menu opens over itself, such as Settings or Controls. A menu instances it
## hidden and calls [method open], which hides the menu's own controls while it shows. Back
## ([code]%BackButton[/code]) or Esc hides it again and brings them back, with focus on the
## control that opened it.

var _covered: Control
var _opener: Control


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	(%BackButton as Button).pressed.connect(hide)


## Shows the screen, its first control focused. [param covered] holds the opening menu's
## controls, hidden until the screen hides. Does nothing while it's already open, so the
## focus it hands back stays the opener's.
func open(covered: Control) -> void:
	if _covered != null:
		return
	_covered = covered
	_opener = get_viewport().gui_get_focus_owner()
	_covered.hide()
	_opening()
	show()
	_first_control().grab_focus()


## Called as the screen opens, before it shows.
func _opening() -> void:
	pass


## The control focused as the screen opens.
func _first_control() -> Control:
	return %BackButton


# Hidden by Back, Esc or the menu that opened it, so it hands focus back here.
func _on_visibility_changed() -> void:
	if visible or _covered == null:
		return
	_covered.show()
	_covered = null
	if is_instance_valid(_opener):
		_opener.grab_focus()


# Esc goes back, like the Back button, and stops there: the pause menu under the screen
# also closes on Esc, which would resume the game.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
