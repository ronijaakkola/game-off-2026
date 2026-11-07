extends GdUnitTestSuite
## The open planet's panel: its name, and a row for each passenger waiting there that
## follows the line as they arrive and board. Then in the solar system: the left clicks
## that open and close a planet, and what the camera, names and borders do meanwhile.

const SCENE := "res://game/solar_system/planet_panel.tscn"
const SOLAR_SYSTEM := "res://game/solar_system/solar_system.tscn"
const COMMUTER := preload("res://game/passengers/types/commuter.tres")

var _waiting: WaitingPassengers
var _home: Planet
var _away: Planet


func before_test() -> void:
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_home = Planet.new()
	_home.display_name = "Home"
	_away = Planet.new()
	_away.display_name = "Away"
	_away.orbit_radius = 6.0
	space.add_child(_home)
	space.add_child(_away)
	_waiting = auto_free(WaitingPassengers.new())
	_waiting.types = [COMMUTER]
	_waiting.max_per_planet = 3
	add_child(_waiting)
	# No one turns up by themselves during a test.
	_waiting.set_process(false)
	_waiting.set_planets([_home, _away])


func test_opens_hidden_and_shows_the_planet_and_who_waits_there() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as PlanetPanel
	panel.waiting = _waiting
	assert_bool(panel.visible).is_false()
	_waiting.add(_home)
	_waiting.add(_home)
	_waiting.add(_away)

	panel.open(_home)

	assert_bool(panel.visible).is_true()
	assert_str((runner.find_child("PlanetNameLabel") as Label).text).is_equal("Home")
	var rows := _rows(runner)
	assert_int(rows.size()).is_equal(2)
	var shown := rows.map(
		func(row: Node) -> Passenger: return (row as WaitingPassengerRow).passenger
	)
	# Longest waiting first.
	assert_array(shown).contains_exactly(_waiting.get_waiting(_home))
	assert_bool((runner.find_child("EmptyLabel") as Label).visible).is_false()
	var first := rows[0] as WaitingPassengerRow
	assert_str((first.find_child("DestinationLabel") as Label).text).is_equal("To Away")


func test_rows_follow_the_line_as_passengers_arrive_and_board() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as PlanetPanel
	panel.waiting = _waiting
	panel.open(_home)
	assert_int(_rows(runner).size()).is_equal(0)
	assert_bool((runner.find_child("EmptyLabel") as Label).visible).is_true()

	_waiting.add(_home)
	_waiting.add(_away)
	assert_int(_rows(runner).size()).is_equal(1)

	_waiting.take(_home, _waiting.get_waiting(_home)[0])
	assert_int(_rows(runner).size()).is_equal(0)
	assert_bool((runner.find_child("EmptyLabel") as Label).visible).is_true()


func test_close_button_asks_and_close_slides_out_and_hides() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as PlanetPanel
	panel.waiting = _waiting
	panel.open(_home)
	var monitor := monitor_signals(panel)

	(runner.find_child("CloseButton") as Button).pressed.emit()

	await assert_signal(monitor).is_emitted("close_pressed")
	# It only asks: the parent closes it.
	assert_object(panel.get_planet()).is_same(_home)
	panel.close()
	assert_object(panel.get_planet()).is_null()
	await await_millis(500)
	assert_bool(panel.visible).is_false()


func test_left_click_on_a_planet_opens_it_and_again_closes_it() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.add(terra)
	waiting.add(terra)
	var rig := runner.find_child("CameraRig") as CameraRig

	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))

	assert_object(system.get_open_planet()).is_same(terra)
	assert_bool(rig.is_focused()).is_true()
	assert_bool((runner.find_child("PlanetPanel") as Control).visible).is_true()
	assert_str((runner.find_child("PlanetNameLabel") as Label).text).is_equal("Terra")
	var rows := runner.find_child("WaitingRows") as Node
	assert_int(rows.get_child_count()).is_equal(waiting.count_at(terra))
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("HintBox") as Control).visible).is_false()

	await runner.simulate_frames(2)
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))

	assert_object(system.get_open_planet()).is_null()
	assert_bool(rig.is_focused()).is_false()
	# Not while the panel slides out over it.
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("HintBox") as Control).visible).is_false()
	await await_millis(400)
	assert_bool((runner.find_child("HintBox") as Control).visible).is_true()


func test_open_planet_sits_left_of_the_panel_and_left_click_on_space_closes_it() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	var panel := runner.find_child("PlanetPanel") as PlanetPanel
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await await_millis(1200)

	var on_screen := camera.unproject_position(terra.get_body_global_position())
	assert_float(on_screen.x).is_less(panel.get_global_rect().position.x)
	var rig := runner.find_child("CameraRig") as CameraRig
	assert_float(on_screen.x).is_equal_approx(rig.focus_rect.get_center().x, 2.0)
	# In the middle of the space left of the panel.
	assert_float(on_screen.x).is_equal_approx(panel.get_global_rect().position.x * 0.5, 2.0)

	# Above the planet, clear of it and of the panel.
	_send_click(MOUSE_BUTTON_LEFT, _to_window(camera, Vector2(on_screen.x, 40.0)))

	assert_object(system.get_open_planet()).is_null()


func test_left_click_on_the_panel_keeps_it_open_and_its_close_button_closes_it() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await await_millis(500)
	var sheet := runner.find_child("Sheet") as Control

	_send_click(MOUSE_BUTTON_LEFT, _to_window(camera, sheet.get_global_rect().get_center()))
	_send_release(MOUSE_BUTTON_LEFT, _to_window(camera, sheet.get_global_rect().get_center()))
	assert_object(system.get_open_planet()).is_same(terra)

	var button := runner.find_child("CloseButton") as Button
	_send_click(MOUSE_BUTTON_LEFT, _to_window(camera, button.get_global_rect().get_center()))
	_send_release(MOUSE_BUTTON_LEFT, _to_window(camera, button.get_global_rect().get_center()))

	assert_object(system.get_open_planet()).is_null()
	assert_bool((runner.find_child("CameraRig") as CameraRig).is_focused()).is_false()


func test_left_click_on_another_planet_opens_that_one() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var ember := runner.find_child("Ember") as Planet
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await runner.simulate_frames(1)

	# The camera has barely moved, and the panel is still sliding in at the right edge.
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, ember))

	assert_object(system.get_open_planet()).is_same(ember)
	assert_str((runner.find_child("PlanetNameLabel") as Label).text).is_equal("Ember")
	assert_bool((runner.find_child("CameraRig") as CameraRig).is_focused()).is_true()


func test_right_click_still_sets_course_while_a_planet_is_open() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await runner.simulate_frames(1)

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])
	assert_object((runner.scene() as SolarSystem).get_open_planet()).is_same(terra)


func test_names_fade_out_while_a_planet_is_open_and_back_after() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await await_millis(600)

	assert_float(terra.label_opacity).is_equal(0.0)
	assert_float(giant.label_opacity).is_equal(0.0)

	(runner.scene() as SolarSystem).close_planet()
	await await_millis(600)

	assert_float(terra.label_opacity).is_equal(1.0)
	assert_float(giant.label_opacity).is_equal(1.0)


func test_open_planet_shows_no_hover_border_but_keeps_its_route_border() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	_send_motion(_screen_point(runner, terra))
	await runner.simulate_frames(1)
	assert_int(terra.border).is_equal(Planet.Border.HOVER)
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await await_millis(1200)

	_send_motion(_screen_point(runner, terra))
	await runner.simulate_frames(2)
	assert_int(terra.border).is_equal(Planet.Border.NONE)

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	await runner.simulate_frames(2)
	assert_int(terra.border).is_equal(Planet.Border.ROUTE)


func test_the_panel_slides_in_with_the_camera_blend() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var rig := runner.find_child("CameraRig") as CameraRig
	var panel := runner.find_child("PlanetPanel") as PlanetPanel
	assert_float(rig.get_focus_seconds()).is_greater(0.0)
	assert_float(panel.slide_in_seconds).is_equal(rig.get_focus_seconds())


func test_the_preview_opens_terra_with_three_waiting() -> void:
	var runner := scene_runner("res://test/previews/solar_system_preview.tscn")
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var system := runner.find_child("SolarSystem") as SolarSystem
	assert_object(system.get_open_planet()).is_same(terra)
	assert_int((runner.find_child("WaitingRows") as Node).get_child_count()).is_equal(3)


func _rows(runner: GdUnitSceneRunner) -> Array[Node]:
	return (runner.find_child("WaitingRows") as Node).get_children()


func _screen_point(runner: GdUnitSceneRunner, planet: Planet) -> Vector2:
	var camera := runner.find_child("Camera") as Camera3D
	return _to_window(camera, camera.unproject_position(planet.get_body_global_position()))


# Where a viewport point is in window pixels, which a sent event carries: the viewport's
# own pixels differ by the window's stretch.
func _to_window(camera: Camera3D, viewport_point: Vector2) -> Vector2:
	return camera.get_viewport().get_final_transform() * viewport_point


# Through Input alone: the runner's own calls deliver each event twice to the root.
func _send_click(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_release(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_motion(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	Input.parse_input_event(event)
	Input.flush_buffered_events()
