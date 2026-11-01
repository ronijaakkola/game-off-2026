extends CanvasLayer
## Pauses the game scene that instances it. The pause action (Esc) opens and closes it, and
## on the web, leaving browser fullscreen opens it.
## It starts hidden, so a game scene only instances it. It processes always, so it still
## takes input while the game is paused, and its layer draws it over the game's own UI.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

## Whether the window shrinking opens the menu. In browser fullscreen, Esc only leaves
## fullscreen and the game never receives it, so leaving fullscreen opens the menu, as that Esc
## would have. On only on the web; a test turns it on to reach it.
var opens_when_window_shrinks := OS.has_feature("web")

var _window_size := Vector2i.ZERO


func _ready() -> void:
	_window_size = get_window().size
	get_window().size_changed.connect(_on_window_size_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


# Leaving fullscreen shows as the window shrinking. itch fullscreens the game's iframe from
# outside, so the window mode never changes, and a fullscreen window can be smaller than the
# screen (a notch, display scaling), so neither tells. Shrinking the browser window pauses too.
# The root window's size is the browser's: Godot sets it from the display server just before
# emitting size_changed.
func _on_window_size_changed() -> void:
	var size := get_window().size
	var shrank := size != _window_size and size.x <= _window_size.x and size.y <= _window_size.y
	_window_size = size
	if opens_when_window_shrinks and shrank and not visible:
		open()


## Shows the menu with Resume focused, and pauses the game.
func open() -> void:
	show()
	%ResumeButton.grab_focus()
	get_tree().paused = true


## Hides the menu, and the settings panel if it's open, and unpauses the game.
func close() -> void:
	%SettingsMenu.hide()
	hide()
	get_tree().paused = false


func _on_resume_button_pressed() -> void:
	close()


func _on_settings_button_pressed() -> void:
	%SettingsMenu.open(%Items)


func _on_main_menu_button_pressed() -> void:
	SceneFlow.go_to(MAIN_MENU_SCENE)
