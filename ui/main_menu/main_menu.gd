extends Control
## The main scene: the logo over the menus' background, and under it the main menu's
## slanted buttons. With no level in progress Play opens the campaign screen; with one,
## Continue plays it straight away and names it, and Levels opens the campaign screen.
## Settings, Controls and Credits open their screens over the background, the menu's rows
## staggering out as they come in ([MenuScreen]), and the campaign screen pans the
## background to its other half as it opens. On the web, a "Click to start" title
## card comes first, because Safari starts audio only after a click in the game.
## The debug panel's Delete save resets the campaign and forgets the tutorial, so the game
## starts as on a first visit, its Reset settings puts every setting back to its default,
## its Voice lab opens the scene for trying the alien voices, and its Mixer opens the scene
## for setting how loud each sound and voice is.

const VOICE_LAB_SCENE := "res://game/transmissions/voice_lab.tscn"
const MIXER_SCENE := "res://ui/mixer/mixer.tscn"
const MUSIC := preload("res://ui/audio/bgm1.ogg")

# Survives scene changes, so coming back to the menu doesn't ask for the click again.
static var _music_started := false


func _ready() -> void:
	%QuitButton.visible = not OS.has_feature("web")
	_show_level_buttons()
	DebugPanel.add_button("Delete save", _debug_delete_save, self)
	DebugPanel.add_button("Reset settings", Settings.reset, self)
	DebugPanel.add_button("Voice lab", _debug_voice_lab, self)
	DebugPanel.add_button("Mixer", _debug_mixer, self)
	%CampaignScreen.visibility_changed.connect(_on_campaign_screen_visibility_changed)
	# The cards come in once the pan has all but settled, and the menu's rows on the way back.
	%CampaignScreen.enter_delay = MenuBackground.PAN_SECONDS * 0.8
	if OS.has_feature("web") and not _music_started:
		%StartOverlay.show()
	else:
		_start_music()
		# Deferred, as the grab_focus docs advise for a call from _ready().
		FocusRing.grab.call_deferred(_first_button())


func _start_music() -> void:
	_music_started = true
	Audio.play_music(MUSIC)


func _on_start_overlay_gui_input(event: InputEvent) -> void:
	# A wheel turn isn't a click to the browser, so it wouldn't start the audio.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		%StartOverlay.hide()
		_start_music()
		FocusRing.grab(_first_button())


# Continue, naming the level, and Levels while a level is in progress, else Play.
func _show_level_buttons() -> void:
	var level := Campaign.get_in_progress()
	%ContinueButton.visible = level != null
	%LevelsButton.visible = level != null
	%PlayButton.visible = level == null
	if level:
		%Where.text = level.title


func _first_button() -> Button:
	return %ContinueButton if %ContinueButton.visible else %PlayButton


# The logo and each plate shown, top to bottom, which stagger out as a screen opens.
func _rows() -> Array[Control]:
	var rows: Array[Control] = [%LogoMargin]
	for plate: Control in %Items.get_children():
		if plate.visible:
			rows.append(plate)
	return rows


func _on_continue_button_pressed() -> void:
	Campaign.play(Campaign.get_in_progress())


func _on_play_button_pressed() -> void:
	%CampaignScreen.open(%Home, _rows)


func _on_levels_button_pressed() -> void:
	%CampaignScreen.open(%Home, _rows)


func _on_settings_button_pressed() -> void:
	%SettingsMenu.open(%Home, _rows)


func _on_controls_button_pressed() -> void:
	%ControlsScreen.open(%Home, _rows)


func _on_credits_button_pressed() -> void:
	%CreditsScreen.open(%Home, _rows)


# Reset from the settings screen: the menu under it shows as on a first visit. Its
# Settings button keeps focus for when the screen closes.
func _on_settings_menu_campaign_reset() -> void:
	_show_level_buttons()


func _on_campaign_screen_visibility_changed() -> void:
	(%Background as MenuBackground).pan_to(%CampaignScreen.is_open())


# The debug panel's Delete save: the menu shows as on a first visit, Play focused, and the
# next run has the tutorial.
func _debug_delete_save() -> void:
	Campaign.reset()
	_show_level_buttons()
	FocusRing.grab(_first_button())


# The debug panel's Voice lab: the scene for trying the alien voices.
func _debug_voice_lab() -> void:
	SceneFlow.go_to(VOICE_LAB_SCENE)


# The debug panel's Mixer: the scene for setting how loud each sound and voice is.
func _debug_mixer() -> void:
	SceneFlow.go_to(MIXER_SCENE)


func _on_quit_button_pressed() -> void:
	# Quits the way the window's close button does, so Talo sends its queued events first.
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
