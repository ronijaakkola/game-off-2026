extends Node
## The main menu with made-up campaign progress, for capturing its screens. `uv run
## tools/check.py capture res://test/previews/main_menu_preview.tscn`, with any of these
## after `--`: `progress` (Level 1 done, Level 2 in progress), `campaign`, `settings`,
## `controls`, and with `campaign`, `restart` or `level1` (Level 1 picked). With `back`, the
## screen goes back to the menu 1.5 s in, and with `settings progress reset back` the
## campaign is reset first, as its hold-to-reset button does.
## It uses a test's own save files, so the player's stay as they are.


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	SaveGame.use_test_files("main_menu_preview")
	SaveGame.delete()
	if "progress" in args:
		SaveGame.write({"star_map": {"opened": 2, "joined": false, "system": "Lyra"}})
		SaveGame.write_campaign({"done": 1, "starts": {}})


# Presses the menu's own buttons, so a capture shows the screens' transitions too.
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# As a player would, after the screens' warm-up frame.
	await get_tree().process_frame
	await get_tree().process_frame
	if "campaign" in args:
		var campaign := $MainMenu.find_child("CampaignScreen")
		var opener := "LevelsButton" if "progress" in args else "PlayButton"
		($MainMenu.find_child(opener) as Button).pressed.emit()
		if "level1" in args:
			(campaign.find_child("Cards").get_child(0) as Button).grab_focus()
		if "restart" in args:
			(campaign.find_child("RestartButton") as Button).pressed.emit()
	elif "settings" in args:
		($MainMenu.find_child("SettingsButton") as Button).pressed.emit()
	elif "controls" in args:
		($MainMenu.find_child("ControlsButton") as Button).pressed.emit()
	if "reset" in args:
		await get_tree().create_timer(1.0).timeout
		($MainMenu.find_child("ResetCampaignButton") as HoldButton).confirmed.emit()
	if "back" in args:
		await get_tree().create_timer(1.5).timeout
		for screen: MenuScreen in $MainMenu.find_children("*", "MenuScreen", true, false):
			if screen.visible:
				screen.close()


func _exit_tree() -> void:
	SaveGame.use_player_files()
