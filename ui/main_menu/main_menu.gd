extends MarginContainer
## The main scene: title, Play, Settings and Quit. On the web, a "Click to start"
## title card comes first, because Safari starts audio only after a click in the game.

const GAME_SCENE := "res://game/game.tscn"
const MUSIC := preload("res://shared/audio/menu_music.ogg")
# Written into exports by `check.py export`, so the editor has none.
const BUILD_COMMIT := "res://ui/main_menu/build_commit.txt"

# Survives scene changes, so coming back to the menu doesn't ask for the click again.
static var _music_started := false


func _ready() -> void:
	%QuitButton.visible = not OS.has_feature("web")
	if FileAccess.file_exists(BUILD_COMMIT):
		%BuildLabel.text = "Commit %s" % FileAccess.get_file_as_string(BUILD_COMMIT).strip_edges()
		%BuildLabel.show()
	if OS.has_feature("web") and not _music_started:
		%StartOverlay.show()
	else:
		_start_music()


func _start_music() -> void:
	_music_started = true
	Audio.play_music(MUSIC)


func _on_start_overlay_gui_input(event: InputEvent) -> void:
	# A wheel turn isn't a click to the browser, so it wouldn't start the audio.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		%StartOverlay.hide()
		_start_music()


func _on_play_button_pressed() -> void:
	SceneFlow.go_to(GAME_SCENE)


func _on_settings_button_pressed() -> void:
	%SettingsMenu.open()


func _on_quit_button_pressed() -> void:
	# Quits the way the window's close button does, so Talo sends its queued events first.
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
