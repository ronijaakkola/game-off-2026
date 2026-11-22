extends Node
## The main menu with made-up campaign progress, for capturing its screens. `uv run
## tools/check.py capture res://test/previews/main_menu_preview.tscn`, with any of these
## after `--`: `progress` (Level 1 done, Level 2 in progress), `campaign`, `settings`,
## `controls`, and with `campaign`, `restart` or `level1` (Level 1 picked).
## It uses a test's own save files, so the player's stay as they are.


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	SaveGame.use_test_files("main_menu_preview")
	SaveGame.delete()
	if "progress" in args:
		SaveGame.write({"star_map": {"opened": 2, "joined": false, "system": "Lyra"}})
		SaveGame.write_campaign({"done": 1, "starts": {}})


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var home := $MainMenu.find_child("Home") as Control
	if "campaign" in args:
		var campaign := $MainMenu.find_child("CampaignScreen")
		campaign.call("open", home)
		if "level1" in args:
			(campaign.find_child("Cards").get_child(0) as Button).pressed.emit()
		if "restart" in args:
			(campaign.find_child("RestartButton") as Button).pressed.emit()
	elif "settings" in args:
		$MainMenu.find_child("SettingsMenu").call("open", home)
	elif "controls" in args:
		$MainMenu.find_child("ControlsScreen").call("open", home)


func _exit_tree() -> void:
	SaveGame.use_player_files()
