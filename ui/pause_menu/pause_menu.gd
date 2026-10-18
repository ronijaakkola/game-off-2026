extends CanvasLayer
## Pauses the game scene that instances it. The pause action (Esc) opens and closes it, and
## on the web, leaving browser fullscreen opens it.
## A game scene instances it hidden. It processes always, so it still takes input while
## the game is paused, and its layer draws it over the game's own UI.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

var _was_fullscreen := false


func _ready() -> void:
	# In browser fullscreen, Esc only leaves fullscreen and the game never receives it. So
	# leaving fullscreen opens the menu, as that Esc would have.
	if OS.has_feature("web"):
		_was_fullscreen = _is_fullscreen()
		get_window().size_changed.connect(_on_window_size_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


func _on_window_size_changed() -> void:
	var fullscreen := _is_fullscreen()
	if _was_fullscreen and not fullscreen and not visible:
		open()
	_was_fullscreen = fullscreen


# itch's fullscreen button makes the game's iframe fullscreen from outside, so the window
# mode never changes. A window as large as the screen is fullscreen.
func _is_fullscreen() -> bool:
	var window := DisplayServer.window_get_size()
	var screen := DisplayServer.screen_get_size()
	return window.x >= screen.x and window.y >= screen.y


## Shows the menu and pauses the game.
func open() -> void:
	show()
	get_tree().paused = true


## Hides the menu, and the settings panel if it's open, and unpauses the game.
func close() -> void:
	%SettingsMenu.hide()
	hide()
	get_tree().paused = false


func _on_resume_button_pressed() -> void:
	close()


func _on_settings_button_pressed() -> void:
	%SettingsMenu.open()


func _on_main_menu_button_pressed() -> void:
	SceneFlow.go_to(MAIN_MENU_SCENE)
