extends GdUnitTestSuite
## The open bus's panel: a row for each of the bus's stats with its value and what upgrades
## add to it, kept up to date as they change. Then in the solar system: the left clicks that
## open and close the bus, and how it trades places with an open planet.

const SCENE := "res://game/bus/bus_panel.tscn"
const BUS := "res://game/bus/bus.tscn"
const SOLAR_SYSTEM := "res://game/solar_system/solar_system.tscn"


func test_shows_each_stat_and_what_upgrades_add_and_take_away_as_they_change() -> void:
	var bus := auto_free((load(BUS) as PackedScene).instantiate()) as FrameshiftBus
	add_child(bus)
	var stats := bus.get_stats()
	# As the solar system's cabin sets it.
	stats.get_stat(BusStats.Type.SEATS).base = 4.0
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as BusPanel
	assert_bool(panel.visible).is_false()
	panel.open(bus)
	assert_bool(panel.visible).is_true()
	var seats := _row(runner, BusStats.Type.SEATS)
	assert_bool(_row_label(seats, "BonusLabel").visible).is_false()

	stats.add_modifier(StatModifier.new(BusStats.Type.SEATS, StatModifier.Kind.FLAT, 1.0))
	var smaller := StatModifier.new(BusStats.Type.FUEL_CAPACITY, StatModifier.Kind.PERCENT, -20.0)
	stats.add_modifier(smaller)

	assert_bool(_row_label(seats, "BonusLabel").visible).is_true()
	assert_str(_row_label(seats, "NameLabel").text).is_equal("Seats")
	assert_str(_row_label(seats, "ValueLabel").text).is_equal("5")
	assert_str(_row_label(seats, "BonusLabel").text).is_equal("+1")
	var fuel := _row(runner, BusStats.Type.FUEL_CAPACITY)
	assert_str(_row_label(fuel, "NameLabel").text).is_equal("Fuel tank")
	assert_str(_row_label(fuel, "ValueLabel").text).is_equal("80")
	var penalty := _row_label(fuel, "BonusLabel")
	assert_str(penalty.text).is_equal("-20%")
	assert_object(penalty.get_theme_color(&"font_color")).is_equal(BusPanel.PENALTY_COLOR)


func test_shows_the_traits_the_bus_has_as_they_come_and_go() -> void:
	var bus := auto_free((load(BUS) as PackedScene).instantiate()) as FrameshiftBus
	add_child(bus)
	var traits := bus.get_stats().get_traits()
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as BusPanel
	panel.open(bus)
	var none := runner.find_child("NoTraitsLabel") as Label
	var forecast := runner.find_child("TraitLabel") as Label
	assert_bool(none.visible).is_true()
	assert_bool(forecast.visible).is_false()

	traits.add(BusTraits.Type.FUEL_FORECAST)

	assert_bool(none.visible).is_false()
	assert_bool(forecast.visible).is_true()
	assert_str(forecast.text).is_equal("Fuel forecast")

	traits.remove(BusTraits.Type.FUEL_FORECAST)

	assert_bool(none.visible).is_true()
	assert_bool(forecast.visible).is_false()


func test_left_click_on_the_bus_opens_it_and_again_closes_it() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var rig := runner.find_child("CameraRig") as CameraRig

	_send_click(MOUSE_BUTTON_LEFT, _bus_screen_point(runner))

	assert_bool(system.is_bus_open()).is_true()
	assert_object(system.get_open_planet()).is_null()
	assert_bool(rig.is_focused()).is_true()
	assert_bool((runner.find_child("BusPanel") as Control).visible).is_true()
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("HintBox") as Control).visible).is_false()

	await runner.simulate_frames(2)
	_send_click(MOUSE_BUTTON_LEFT, _bus_screen_point(runner))

	assert_bool(system.is_bus_open()).is_false()
	assert_bool(rig.is_focused()).is_false()


func test_the_open_bus_sits_left_of_its_panel_and_opening_a_planet_closes_it() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var bus := runner.find_child("Bus") as FrameshiftBus
	var camera := runner.find_child("Camera") as Camera3D
	var panel := runner.find_child("BusPanel") as BusPanel
	var rig := runner.find_child("CameraRig") as CameraRig
	_send_click(MOUSE_BUTTON_LEFT, _bus_screen_point(runner))
	await await_signal_on(rig, "focus_blend_finished", [], 5000)
	# Read at a frame's start: mid-frame, the bus has moved but the camera not yet after it.
	await get_tree().process_frame

	var on_screen := camera.unproject_position(bus.global_position)
	assert_float(on_screen.x).is_equal_approx(panel.get_global_rect().position.x * 0.5, 2.0)

	var terra := runner.find_child("Terra") as Planet
	system.open_planet(terra)

	assert_bool(system.is_bus_open()).is_false()
	assert_object(system.get_open_planet()).is_same(terra)
	assert_bool(rig.is_focused()).is_true()
	await await_millis(400)
	assert_bool(panel.visible).is_false()


func test_the_pointer_over_the_bus_shows_its_border_unless_it_is_open() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var model := (runner.find_child("Bus") as FrameshiftBus).get_model()
	var ember := runner.find_child("Ember") as Planet
	var camera := runner.find_child("Camera") as Camera3D

	_send_motion(_bus_screen_point(runner))
	await runner.simulate_frames(1)
	assert_bool(model.border).is_true()
	# Docked beside Ember, the bus wins where it is nearer the pointer, as a click does.
	assert_int(ember.border).is_equal(Planet.Border.NONE)

	var on_ember := camera.unproject_position(ember.get_body_global_position())
	_send_motion(_to_window(camera, on_ember))
	await runner.simulate_frames(1)
	assert_bool(model.border).is_false()
	assert_int(ember.border).is_equal(Planet.Border.HOVER)

	system.open_bus()
	await runner.simulate_frames(1)
	_send_motion(_bus_screen_point(runner))
	await runner.simulate_frames(1)
	assert_bool(model.border).is_false()


# The rows are in the order of BusStats.Type.
func _row(runner: GdUnitSceneRunner, type: BusStats.Type) -> Node:
	return runner.find_child("StatRows").get_child(type)


func _row_label(row: Node, label_name: String) -> Label:
	return row.find_child(label_name, false, false) as Label


func _bus_screen_point(runner: GdUnitSceneRunner) -> Vector2:
	var camera := runner.find_child("Camera") as Camera3D
	var bus := runner.find_child("Bus") as FrameshiftBus
	return _to_window(camera, camera.unproject_position(bus.global_position))


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


func _send_motion(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	Input.parse_input_event(event)
	Input.flush_buffered_events()
