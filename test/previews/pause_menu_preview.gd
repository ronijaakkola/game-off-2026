extends Node
## The solar system with the pause menu open over it, for capturing the pause menu (it starts
## hidden, so its own scene renders empty). `uv run tools/check.py capture
## res://test/previews/pause_menu_preview.tscn`; with `-- settings` the settings panel is
## open over it as well.


func _ready() -> void:
	var pause := $SolarSystem.find_child("PauseMenu") as PauseMenu
	pause.open()
	if "settings" in OS.get_cmdline_user_args():
		pause.find_child("SettingsMenu").call("open", pause.find_child("Items"))
