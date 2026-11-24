extends Node
## The solar system with the pause menu open over it, for capturing the pause menu (it starts
## hidden, so its own scene renders empty). `uv run tools/check.py capture
## res://test/previews/pause_menu_preview.tscn`; with `-- settings` the settings panel is
## open over it as well, with `-- controls` the controls screen, with `-- restart` the
## restart dialog, and with `-- tutorial` it offers Skip tutorial as through the tutorial.


func _ready() -> void:
	var pause := $SolarSystem.find_child("PauseMenu") as PauseMenu
	pause.offers_skip_tutorial = "tutorial" in OS.get_cmdline_user_args()
	pause.open()
	if "settings" in OS.get_cmdline_user_args():
		pause.find_child("SettingsMenu").call("open", pause.find_child("Content"))
	if "controls" in OS.get_cmdline_user_args():
		pause.find_child("ControlsScreen").call("open", pause.find_child("Content"))
	if "restart" in OS.get_cmdline_user_args():
		(pause.find_child("RestartButton") as Button).pressed.emit()
