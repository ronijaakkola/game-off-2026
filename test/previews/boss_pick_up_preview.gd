extends Node
## The game started in Sol, docked at Earth, with The Boss's pick-up ([BossPickUp]) begun,
## so the meeting plays at once: the question mark in the line, the transmission and the
## lights coming on, the stargate appearing, The Boss boarding, the stargate's row, the
## map drawing back to the star chart, and The Boss's call about what they left behind,
## with their goals coming in. It answers the transmissions and presses the row by
## itself, so `capture <this scene> --frames N` shows whichever moment N frames in falls on.
## With `quest` after `--` the bus starts at Mars instead, so the quest and the marker over
## Earth show; with `built`, the stargate is already there. One part alone plays at once
## with `gate` (the stargate appearing), `row` (the stargate's row and its guide card) or
## `chart` (the HUD going and the map drawing back) or `errands` (the map drawing back,
## The Boss's call over the chart, and their goals coming in). With `travel`, The Boss is
## on board and the star chart is open to go to another star, the pointer on Lyra; with
## `jump`, the bus then jumps there with a click on the card, docks where the briefcase is,
## jumps back to Sol and closes the chart with its button.

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
		pick_up._gate = find_child("EarthStargate") as Stargate
		pick_up._build_gate()
		return
	if "errands" in args:
		await (find_child("Hud") as HudLayout).hide_all()
		pick_up._send_on_errands(0.0)
		var calling := find_child("TransmissionPanel") as TransmissionPanel
		while not calling.is_open():
			await get_tree().process_frame
		await _answer(calling)
		return
	if "travel" in args or "jump" in args:
		if "jump" in args:
			# Where the bus comes out in Lyra, so the briefcase is fetched as it docks.
			pick_up.briefcase_planet = find_child("Cinder") as Planet
		_travel(pick_up, "jump" in args)
		return
	if "built" in args or "row" in args or "chart" in args:
		pick_up.load_save({"stage": BossPickUp.Stage.BUILT})
		pick_up._busy = "built" not in args
		if "row" in args:
			pick_up._teach_row()
		elif "chart" in args:
			await (find_child("Hud") as HudLayout).hide_all()
			pick_up.star_chart.open(BossPickUp.REVEAL_SECONDS)
		return
	pick_up.begin()
	var panel := find_child("TransmissionPanel") as TransmissionPanel
	while not panel.is_open():
		await get_tree().process_frame
	for part: int in 2:
		await _answer(panel)
	var row := (find_child("DockPanel") as DockPanel).get_stargate_row()
	while not (row.is_open() and get_tree().paused):
		await get_tree().process_frame
	await get_tree().create_timer(PRESS_SECONDS).timeout
	row.pressed.emit()
	while not panel.is_open():
		await get_tree().process_frame
	await _answer(panel)


# Reads what is said, skips to its end and answers.
func _answer(panel: TransmissionPanel) -> void:
	await get_tree().create_timer(READ_SECONDS).timeout
	panel.skip()
	await get_tree().create_timer(ANSWER_SECONDS).timeout
	panel.accept()


# The Boss is on board with the stargate built and the star chart open to go to another
# star, the pointer on Lyra; with [param jumps], the bus goes there.
func _travel(pick_up: BossPickUp, jumps: bool) -> void:
	var boss := BossPassenger.create(find_child("Earth") as Planet)
	BossPassenger.reveal(boss)
	(find_child("Cabin") as Cabin).board(boss)
	(find_child("StarMap") as StarMap).restore({"reached": 3}, find_child("Earth") as Planet)
	pick_up.load_save({"stage": BossPickUp.Stage.BUILT})
	var travel := find_child("StarTravel") as StarTravel
	await travel.open()
	var lyra := (find_child("Lyra") as StarSystem).global_position
	get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(lyra))
	if not jumps:
		return
	# A real click on the card's button, through the HUD's click block.
	await get_tree().create_timer(1.0).timeout
	var button := find_child("StarCard").find_child("JumpButton") as Button
	_click(button.get_global_rect().get_center())
	var chart := find_child("StarChart") as StarChart
	await chart.closed
	var bus := find_child("Bus") as FrameshiftBus
	await bus.docked
	await get_tree().create_timer(1.0).timeout
	# Back to Sol: Vela is too far from there, so its button does nothing.
	await travel.open()
	travel._star = find_child("Sol") as StarSystem
	travel._on_jump_pressed()
	await chart.closed
	await bus.docked
	await travel.open()
	_click((find_child("CloseStarChart") as Button).get_global_rect().get_center())
	await chart.closed


func _click(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		get_viewport().push_input(click)
