extends CanvasLayer
## Pauses the game scene that instances it. The pause action (Esc) opens and closes it.
## A game scene instances it hidden. It processes always, so it still takes input while
## the game is paused, and its layer draws it over the game's own UI.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


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
