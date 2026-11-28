extends Node
## The game started in Sol, docked at Earth, with The Boss's pick-up ([BossPickUp]) begun,
## so the meeting plays at once: the question mark in the line, the transmission and the
## lights coming on, the stargate appearing, The Boss boarding, the stargate's row and the
## map drawing back to the star chart. It answers the transmission and presses the row by
## itself, so `capture <this scene> --frames N` shows whichever moment N frames in falls on.
## With `quest` after `--` the bus starts at Mars instead, so the quest and the marker over
## Earth show; with `built`, the stargate is already there. One part alone plays at once
## with `gate` (the stargate appearing), `row` (the stargate's row and its guide card) or
## `chart` (the HUD going and the map drawing back).

## Seconds the transmission shows before the preview skips to its end, then answers.
const READ_SECONDS := 4.5
const ANSWER_SECONDS := 1.2
## Seconds the stargate's row waits before the preview presses it.
const PRESS_SECONDS := 2.0


# Before the solar system's own, so it starts the run in Sol.
func _enter_tree() -> void:
	var bus := find_child("Bus") as FrameshiftBus
	var planet := "Mars" if "quest" in OS.get_cmdline_user_args() else "Earth"
	bus.start_planet = find_child(planet) as Planet


func _ready() -> void:
	await get_tree().process_frame
	(find_child("FirstShiftCall") as FirstShiftCall).cancel()
	(find_child("Hud") as HudLayout).reveal_all()
	var pick_up := find_child("BossPickUp") as BossPickUp
	var args := OS.get_cmdline_user_args()
	if "gate" in args:
		pick_up._gate = Stargate.find(get_tree())
		pick_up._build_gate()
		return
	if "built" in args or "row" in args or "chart" in args:
		pick_up.load_save({"stage": BossPickUp.Stage.BUILT})
		pick_up._busy = "built" not in args
		if "row" in args:
			pick_up._teach_row()
		elif "chart" in args:
			await (find_child("Hud") as HudLayout).hide_all()
			pick_up._show_chart(BossPickUp.REVEAL_SECONDS, BossPickUp.REVEAL_HOLD_SECONDS)
		return
	pick_up.begin()
	var panel := find_child("TransmissionPanel") as TransmissionPanel
	while not panel.is_open():
		await get_tree().process_frame
	for part: int in 2:
		await get_tree().create_timer(READ_SECONDS).timeout
		panel.skip()
		await get_tree().create_timer(ANSWER_SECONDS).timeout
		panel.accept()
	var row := (find_child("DockPanel") as DockPanel).get_stargate_row()
	while not (row.is_open() and get_tree().paused):
		await get_tree().process_frame
	await get_tree().create_timer(PRESS_SECONDS).timeout
	row.pressed.emit()
