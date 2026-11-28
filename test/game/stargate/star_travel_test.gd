extends GdUnitTestSuite
## Travel between stars: with the stargate built and the star chart open, the pointer on
## a star one link away opens its card, and its Jump button takes the bus there. The chart
## closes into that star's system, and the bus flies in to dock beside its stargate
## burning no fuel, so an almost empty tank still gets there.

const SOL := "res://test/previews/sol_preview.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

var _window_size: Vector2i


func before() -> void:
	SaveGame.use_test_files("star_travel")
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)


func after() -> void:
	SaveGame.use_player_files()
	get_tree().root.size = _window_size


func after_test() -> void:
	get_tree().paused = false


func test_jumping_to_lyra_docks_beside_its_stargate_without_burning_fuel() -> void:
	var runner := scene_runner(SOL)
	await runner.simulate_frames(2)
	(runner.find_child("FirstShiftCall") as FirstShiftCall).cancel()
	var star_map := runner.find_child("StarMap") as StarMap
	star_map.restore({"reached": 3}, runner.find_child("Mars") as Planet)
	(runner.find_child("BossPickUp") as BossPickUp).load_save({"stage": BossPickUp.Stage.BUILT})
	var bus := runner.find_child("Bus") as FrameshiftBus
	var tank := bus.get_fuel_tank()
	tank.fuel = 0.5 * tank.burn_per_unit
	var chart := runner.find_child("StarChart") as StarChart
	var travel := runner.find_child("StarTravel") as StarTravel
	await travel.open()
	var lyra := runner.find_child("Lyra") as StarSystem
	var camera := runner.scene().get_viewport().get_camera_3d()

	_send_motion(camera.unproject_position(lyra.global_position))
	var card := runner.find_child("StarCard") as StarCard
	var shown := await PauseProofWait.for_condition(card.is_shown, 2000)
	assert_bool(shown).override_failure_message("Lyra's card never showed").is_true()
	if is_failure():
		return
	await runner.simulate_frames(30)
	_send_click((card.find_child("JumpButton") as Button).get_global_rect().get_center())
	var closed := await PauseProofWait.for_signal(chart.closed, 8000)
	assert_bool(closed).override_failure_message("The chart never closed").is_true()
	if is_failure():
		return
	var docked := func() -> bool: return bus.get_docked_planet() != null
	assert_bool(await PauseProofWait.for_condition(docked, 8000)).is_true()

	assert_object(star_map.get_current()).is_same(lyra)
	assert_object(bus.get_docked_planet()).is_same(Stargate.find(get_tree(), lyra).planet)
	assert_float(tank.fuel).is_equal(0.5 * tank.burn_per_unit)


# Through Input alone, at the window's base size, where its pixels are the viewport's.
func _send_motion(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# A press and its release, which a Button needs to count as pressed.
func _send_click(at: Vector2) -> void:
	_send_motion(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
