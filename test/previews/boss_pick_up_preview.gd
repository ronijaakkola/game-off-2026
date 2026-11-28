extends Node
## The game started in Sol, docked at Earth, with The Boss's pick-up ([BossPickUp]) begun,
## so the meeting plays at once: the question mark in the line, the transmission and the
## lights coming on, the stargate appearing, The Boss boarding, the stargate's row and the
## map drawing back to the star chart. It answers the transmission and presses the row by
## itself, so `capture <this scene> --frames N` shows whichever moment N frames in falls on.
## With `quest` after `--` the bus starts at Mars instead, so the quest and the marker over
## Earth show; with `built`, the stargate is already there. One part alone plays at once
## with `gate` (the stargate appearing), `row` (the stargate's row and its guide card) or
## `chart` (the HUD going and the map drawing back). With `travel`, The Boss is on board and
## the star chart is open to go to another star, the pointer on Lyra; with `jump`, the bus
## then jumps there with a click on the card, docks where its errand is, jumps back to Sol
## and closes the chart with its button, warning with a `TRIP` line at each step. With
## `errand`, The Boss's errand is at Earth, so it is done at once and they are dressed for
## the board.

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
	if "travel" in args or "jump" in args or "errand" in args:
		if "errand" in args:
			(find_child("BossErrand") as BossErrand).planet = find_child("Earth") as Planet
		if "jump" in args:
			# Where the bus comes out in Lyra, so the errand is done as it docks.
			(find_child("BossErrand") as BossErrand).planet = find_child("Cinder") as Planet
		_travel(pick_up, "jump" in args, "errand" not in args)
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


# The Boss is on board with the stargate built and the star chart open to go to another
# star, the pointer on Lyra; with [param jumps], the bus goes there. Without
# [param opens] the chart stays shut.
func _travel(pick_up: BossPickUp, jumps: bool, opens := true) -> void:
	var boss := BossPassenger.create(find_child("Earth") as Planet)
	BossPassenger.reveal(boss)
	(find_child("Cabin") as Cabin).board(boss)
	(find_child("StarMap") as StarMap).restore({"reached": 3}, find_child("Earth") as Planet)
	pick_up.load_save({"stage": BossPickUp.Stage.BUILT})
	if not opens:
		return
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
	var map := find_child("StarMap") as StarMap
	var chart := find_child("StarChart") as StarChart
	await chart.closed
	push_warning("TRIP in ", map.get_current().name, ", jump offered: ", map.get_jump_target())
	var bus := find_child("Bus") as FrameshiftBus
	await bus.docked
	push_warning(
		"TRIP docked at ", bus.get_docked_planet().name, ", dressed: ", boss.type.wears_bow_tie
	)
	await get_tree().create_timer(1.0).timeout
	push_warning(
		"TRIP row open: ", (find_child("DockPanel") as DockPanel).get_stargate_row().is_open()
	)
	# Back to Sol: Vela is too far from there, so its button does nothing.
	await travel.open()
	travel._star = find_child("Sol") as StarSystem
	travel._on_jump_pressed()
	await chart.closed
	push_warning("TRIP back in ", map.get_current().name, ", goals: ", _goal_texts())
	await bus.docked
	push_warning("TRIP docked at ", bus.get_docked_planet().name)
	push_warning("TRIP can reach Vela: ", map.can_travel(find_child("Vela") as StarSystem))
	await travel.open()
	_click((find_child("CloseStarChart") as Button).get_global_rect().get_center())
	await chart.closed
	push_warning("TRIP closed by the button")


func _goal_texts() -> Array:
	var goals := find_child("Goals") as GoalTracker
	return goals.get_goals().map(func(goal: Goal) -> String: return goal.get_text())


func _click(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		get_viewport().push_input(click)
