extends MarginContainer
## The main scene: title, Play, Settings and Quit. With a save game, Continue comes first
## and New game takes Play's place: it starts over and replaces the save, so it has to be
## held, and a stray click can't lose a run. On the web, a "Click to start" title card
## comes first, because Safari starts audio only after a click in the game.
## The debug panel's Delete save button deletes the save and forgets the tutorial, so the
## game starts as on a first visit, its Reset settings puts every setting back to its
## default, its Voice lab opens the scene for trying the alien voices, and its Mixer opens
## the scene for setting how loud each sound and voice is.

const GAME_SCENE := "res://game/solar_system/solar_system.tscn"
const VOICE_LAB_SCENE := "res://game/transmissions/voice_lab.tscn"
const MIXER_SCENE := "res://ui/mixer/mixer.tscn"
const MUSIC := preload("res://ui/audio/bg.ogg")
## The levels, each with its loading screen, until the campaign screen picks one. A run
## shows the one of the star system it starts or continues in.
const LEVELS: Array[Level] = [
	preload("res://shared/level_art/level_1.tres"),
	preload("res://shared/level_art/level_2.tres"),
]

# Survives scene changes, so coming back to the menu doesn't ask for the click again.
static var _music_started := false


func _ready() -> void:
	%QuitButton.visible = not OS.has_feature("web")
	_show_save_buttons()
	DebugPanel.add_button("Delete save", _debug_delete_save, self)
	DebugPanel.add_button("Reset settings", Settings.reset, self)
	DebugPanel.add_button("Voice lab", _debug_voice_lab, self)
	DebugPanel.add_button("Mixer", _debug_mixer, self)
	if OS.has_feature("web") and not _music_started:
		%StartOverlay.show()
	else:
		_start_music()
		# Deferred, as the grab_focus docs advise for a call from _ready().
		_first_button().grab_focus.call_deferred()


func _start_music() -> void:
	_music_started = true
	Audio.play_music(MUSIC)


func _on_start_overlay_gui_input(event: InputEvent) -> void:
	# A wheel turn isn't a click to the browser, so it wouldn't start the audio.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		%StartOverlay.hide()
		_start_music()
		_first_button().grab_focus()


# Continue and New game with a save, else Play.
func _show_save_buttons() -> void:
	var saved := SaveGame.has_save()
	%ContinueButton.visible = saved
	%NewGameButton.visible = saved
	%PlayButton.visible = not saved


# Continue when there is a save to continue, else Play.
func _first_button() -> Button:
	return %ContinueButton if %ContinueButton.visible else %PlayButton


func _on_continue_button_pressed() -> void:
	SaveGame.continue_saved()
	SceneFlow.go_to(GAME_SCENE, _started_level())


func _on_play_button_pressed() -> void:
	SaveGame.start_new()
	SceneFlow.go_to(GAME_SCENE, _started_level())


# The level of the star system the started run is in: Sol for a new run. A save from before
# saves kept the system has none, and loads on the black card.
func _started_level() -> Level:
	var run := SaveGame.get_started_run()
	var star_map: Dictionary = run.get("star_map", {})
	var system: String = star_map.get("system", "") if not run.is_empty() else "Sol"
	for level: Level in LEVELS:
		if level.star_system == system:
			return level
	return null


func _on_new_game_button_confirmed() -> void:
	_on_play_button_pressed()


func _on_settings_button_pressed() -> void:
	%SettingsMenu.open(%Items)


# Deleted from the settings panel: the menu under it shows as with no save. Its Settings
# button keeps focus for when the panel closes.
func _on_settings_menu_save_deleted() -> void:
	_show_save_buttons()


# The debug panel's Delete save: the menu shows as with no save, Play focused, and the
# next run has the tutorial.
func _debug_delete_save() -> void:
	SaveGame.delete()
	_show_save_buttons()
	_first_button().grab_focus()


# The debug panel's Voice lab: the scene for trying the alien voices.
func _debug_voice_lab() -> void:
	SceneFlow.go_to(VOICE_LAB_SCENE)


# The debug panel's Mixer: the scene for setting how loud each sound and voice is.
func _debug_mixer() -> void:
	SceneFlow.go_to(MIXER_SCENE)


func _on_quit_button_pressed() -> void:
	# Quits the way the window's close button does, so Talo sends its queued events first.
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
