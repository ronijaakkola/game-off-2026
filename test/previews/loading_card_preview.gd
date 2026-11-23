extends Node
## A level's loading screen part way through loading, for capturing it (SceneFlow shows it
## only for a moment). `uv run tools/check.py capture
## res://test/previews/loading_card_preview.tscn`; with `-- 2` it shows level 2, and with
## `-- loaded` it shows the Start button the card waits on once loaded.

const LEVELS: Array[String] = [
	"res://shared/level_art/level_1.tres",
	"res://shared/level_art/level_2.tres",
]


func _ready() -> void:
	var level := LEVELS[1] if "2" in OS.get_cmdline_user_args() else LEVELS[0]
	var card := $LoadingCard as LoadingCard
	card.show_level(load(level))
	card.set_progress(0.45)
	if "loaded" in OS.get_cmdline_user_args():
		card.wait_for_start()
