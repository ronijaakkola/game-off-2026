extends Node
## The game started docked at Earth, in Sol, with the star chart opening after a moment,
## for capturing the pull back: `capture <this scene> --frames 480`. With a planet's name
## after `--` it starts docked there instead, in that planet's system, as `-- Hither` does
## for Lyra, and with "back" the chart closes again once open.

## Seconds of play before the chart opens.
const WAIT_SECONDS := 0.5
## Seconds it stays open before it closes, long enough to see that nothing on it moves.
const HOLD_SECONDS := 2.0


# Before the solar system's own, so it starts the run in that planet's system.
func _enter_tree() -> void:
	var home := find_child("Earth") as Planet
	for arg: String in OS.get_cmdline_user_args():
		if find_child(arg) is Planet:
			home = find_child(arg) as Planet
	(find_child("Bus") as FrameshiftBus).start_planet = home


func _ready() -> void:
	var chart := find_child("StarChart") as StarChart
	await get_tree().create_timer(WAIT_SECONDS).timeout
	chart.open()
	if "back" in OS.get_cmdline_user_args():
		await chart.opened
		await get_tree().create_timer(HOLD_SECONDS).timeout
		chart.close()
