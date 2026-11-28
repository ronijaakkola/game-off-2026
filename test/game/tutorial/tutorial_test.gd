extends GdUnitTestSuite
## A new run opens on the boss's call with only the bus bars showing; answering it with
## either of the two answers starts the steps on the guide card beside the bus, and the
## camera's card after it waits for the player to both pan and zoom the camera. Through the
## call, the menu button still opens the pause menu. Skipping the tutorial puts back every
## rule it changed and fills the tank, and the next new run starts without it. On the way
## home a capsule of credits waits still on the spot, and the fare and it make 120 credits.

const SCENE := "res://game/solar_system/solar_system.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

var _window_size: Vector2i


func before() -> void:
	SaveGame.use_test_files("tutorial")
	# Headless, the window is 64×64 and the canvas_items stretch would scale every click.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	SaveGame.use_player_files()
	get_tree().root.size = _window_size


func before_test() -> void:
	# A test that ends the tutorial keeps it as done, and the next would start without it.
	SaveGame.delete()


func after_test() -> void:
	get_tree().paused = false


func test_a_new_run_opens_on_the_call_and_answering_it_starts_the_steps() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	assert_bool((runner.find_child("PassengerPanel") as Control).visible).is_false()
	assert_bool((runner.find_child("TopRight") as Control).visible).is_false()
	assert_bool((runner.find_child("BusStatusPanel") as Control).visible).is_true()

	# Once the screen has faded in, the call comes.
	var notices := runner.find_child("Notices") as NoticeStack
	await assert_func(self, "_has_notice", [notices]).wait_until(5000).is_true()
	await runner.simulate_frames(30)
	_click(runner, notices.get_notices()[0].find_child("ActionButton") as Control)
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	panel.skip()
	await runner.simulate_frames(60)
	assert_str((panel.find_child("CallerName") as Label).text).is_equal("Your Boss")

	# Either answer goes on.
	_click(runner, panel.find_child("DeclineButton") as Control)
	var answered := await PauseProofWait.for_signal(panel.answered, 3000)
	assert_bool(answered).override_failure_message("The call never closed").is_true()
	if is_failure():
		return
	var guide := runner.find_child("GuideCard") as GuideCard
	await assert_func(guide, "is_visible_in_tree").wait_until(2000).is_true()
	assert_str(guide.text).starts_with("You are driving this bus.")


func test_the_menu_button_opens_the_pause_menu_while_the_call_covers_the_screen() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var notices := runner.find_child("Notices") as NoticeStack
	await assert_func(self, "_has_notice", [notices]).wait_until(5000).is_true()
	await runner.simulate_frames(30)

	# The rest of the screen still takes no clicks.
	var bars := runner.find_child("BusStatusPanel") as Control
	runner.set_mouse_position(bars.get_global_rect().get_center())
	await runner.simulate_frames(2)
	var hovered := bars.get_viewport().gui_get_hovered_control()
	assert_str(hovered.name if hovered else "").is_equal("ClickBlock")
	var pause_button := runner.find_child("PauseButton").find_child("Button") as Control
	_click(runner, pause_button)
	await runner.simulate_frames(5)
	assert_bool((runner.find_child("PauseMenu") as CanvasLayer).visible).is_true()


func test_after_boarding_a_card_on_the_passenger_goes_on_to_the_course() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var notices := runner.find_child("Notices") as NoticeStack
	await assert_func(self, "_has_notice", [notices]).wait_until(5000).is_true()
	await runner.simulate_frames(30)
	_click(runner, notices.get_notices()[0].find_child("ActionButton") as Control)
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	panel.skip()
	await runner.simulate_frames(60)
	_click(runner, panel.find_child("DeclineButton") as Control)
	await PauseProofWait.for_signal(panel.answered, 3000)
	var guide := runner.find_child("GuideCard") as GuideCard
	await _wait_for_card(guide, "You are driving this bus.")
	_click(runner, guide.find_child("GotItButton") as Control)

	# The camera card waits until the player has moved the camera.
	await _wait_for_card(guide, "Hold {mouse_left} and drag")
	await runner.simulate_frames(30)
	assert_bool(guide.text.begins_with("Hold {mouse_left} and drag")).is_true()
	runner.simulate_action_press(&"camera_pan_right")
	await runner.simulate_frames(30, 16)
	runner.simulate_action_release(&"camera_pan_right")
	# Panning alone isn't enough: the card waits for a zoom too.
	await runner.simulate_frames(60, 16)
	assert_bool(guide.text.begins_with("Hold {mouse_left} and drag")).is_true()
	(runner.find_child("CameraRig") as CameraRig).zoom_to(30.0)
	await runner.simulate_frames(30, 16)

	var dock := runner.find_child("DockPanel") as DockPanel
	var waiting := (runner.find_child("Tutorial") as Tutorial).waiting
	var home := runner.find_child("Terra") as Planet
	await assert_func(self, "_has_row", [dock, waiting, home]).wait_until(5000).is_true()
	var row := dock.get_row(waiting.get_waiting(home)[0])
	# Once the station panel is in, the card on the row opens.
	await _wait_for_card(guide, "Here you can see a list of waiting passengers.")
	_click(runner, row.find_child("BoardButton") as Control)
	# One card on the passenger's card says they are on board and what their bar shows.
	await _wait_for_card(guide, "Your passenger is on board.")
	var cabin := runner.find_child("Cabin") as Cabin
	var passengers := runner.find_child("PassengerPanel") as PassengerPanel
	var card := passengers.get_card(cabin.get_passengers()[0])
	assert_object(guide.target).is_same(card)
	assert_bool(guide.got_it).is_true()

	_click(runner, guide.find_child("GotItButton") as Control)
	await _wait_for_card(guide, "Your passenger wants to go to")


func test_skipping_puts_back_what_it_changed() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var moon := runner.find_child("Moon") as Planet
	assert_float(moon.fuel_price).is_zero()

	(runner.find_child("Tutorial") as Tutorial).skip()

	assert_float(moon.fuel_price).is_greater(0.0)
	var dock := runner.find_child("DockPanel") as DockPanel
	assert_bool(dock.fuel_hidden or dock.fuel_locked or dock.board_all_hidden).is_false()
	assert_bool((runner.find_child("Bus") as FrameshiftBus).route_locked).is_false()


func test_on_the_way_home_a_capsule_on_the_spot_pays_the_rest_of_the_tutorials_credits() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var tutorial := runner.find_child("Tutorial") as Tutorial
	var capsules := runner.find_child("CapsuleField") as CapsuleField
	var ledger := (runner.scene() as SolarSystem).get_ledger()
	var before := ledger.credits

	var way_home := WayHome.new(tutorial, TutorialRules.new(tutorial))
	await runner.simulate_frames(30)
	assert_int(capsules.get_capsules().size()).is_equal(1)
	var capsule := capsules.get_capsules()[0]
	assert_vector(capsule.get_flat_position()).is_equal_approx(
		way_home.get_spot(), Vector3.ONE * 0.01
	)
	var bus := tutorial.bus
	bus.fly_in(RouteStop.at_point(way_home.get_spot()), bus.max_speed)
	await assert_func(self, "_is_holding", [bus]).wait_until(20000).is_true()
	await runner.simulate_frames(2)

	assert_array(capsules.get_capsules()).is_empty()
	assert_int(ledger.credits - before).is_equal(TutorialRules.CAPSULE_CREDITS)
	assert_float(TutorialRules.FARE + TutorialRules.CAPSULE_CREDITS).is_equal(120.0)


func test_skipping_takes_away_the_capsule_on_the_way_home() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var tutorial := runner.find_child("Tutorial") as Tutorial
	WayHome.new(tutorial, TutorialRules.new(tutorial))

	tutorial.skip()

	assert_array((runner.find_child("CapsuleField") as CapsuleField).get_capsules()).is_empty()


func test_the_run_starts_on_a_full_tank_after_the_tutorial() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var tank := (runner.find_child("Bus") as FrameshiftBus).get_fuel_tank()
	# As after the tutorial's trip.
	tank.fuel = tank.capacity * 0.5

	(runner.find_child("Tutorial") as Tutorial).skip()

	assert_float(tank.get_fraction()).is_equal(1.0)


func test_a_new_run_after_the_tutorial_starts_without_it() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	(runner.find_child("Tutorial") as Tutorial).skip()
	assert_bool(SaveGame.is_tutorial_done()).is_true()

	SaveGame.start_new()
	runner = scene_runner(SCENE)
	await runner.simulate_frames(2)
	assert_bool((runner.find_child("MapZoom") as MapZoom).is_zoomed()).is_false()
	assert_bool((runner.find_child("Tutorial") as Tutorial).is_running()).is_false()


# The zoomed map rescaled the star's meshes, the heat zone's disc among them, and left it
# 2 units across inside the star once the map zoomed out: the zone never showed.
func test_the_heat_zone_fades_in_full_size_once_the_map_zooms_out() -> void:
	SaveGame.start_new()
	var reduce_motion := Settings.reduce_motion
	Settings.reduce_motion = true
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var disc := runner.find_child("HeatZoneDisc") as MeshInstance3D
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_bool(disc.visible).is_false()
	(runner.find_child("MapZoom") as MapZoom).settle_seconds = 0.0

	(runner.find_child("Tutorial") as Tutorial).skip()
	await await_millis(int(HeatZone.FADE_SECONDS * 1000.0) + 400)
	Settings.reduce_motion = reduce_motion

	assert_bool(disc.visible).is_true()
	assert_float(disc.scale.x).is_equal_approx(bus.temperature.zone_radius, 0.001)
	var material := disc.material_override as ShaderMaterial
	assert_float(material.get_shader_parameter(&"opacity") as float).is_equal_approx(1.0, 0.001)


# Waits until the guide card shows the card that starts with [param text], fully open.
func _is_holding(bus: FrameshiftBus) -> bool:
	return bus.state == FrameshiftBus.State.HOLDING


func _wait_for_card(guide: GuideCard, text: String) -> void:
	await assert_func(self, "_shows_card", [guide, text]).wait_until(5000).is_true()
	await await_millis(int(Tooltip.OPEN_SECONDS * 1000.0) + 100)


func _shows_card(guide: GuideCard, text: String) -> bool:
	return guide.is_visible_in_tree() and guide.text.begins_with(text)


func _has_row(dock: DockPanel, waiting: WaitingPassengers, home: Planet) -> bool:
	var line := waiting.get_waiting(home)
	return not line.is_empty() and dock.get_row(line[0]) != null


func _has_notice(notices: NoticeStack) -> bool:
	return not notices.get_notices().is_empty()


func _click(runner: GdUnitSceneRunner, control: Control) -> void:
	runner.set_mouse_position(control.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
