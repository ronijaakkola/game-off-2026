extends GdUnitTestSuite
## The route bar's line of stops.

var _window_size: Vector2i


# Headless, the window is 64x64, and the canvas_items stretch would scale every simulated
# pointer move. At the base size it scales by 1.
func before() -> void:
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)


func after() -> void:
	get_tree().root.size = _window_size


# A stop pushed out and shown again within its fade, as a fold can do to the last one,
# blinked out and slid in again: its leaving fade ran on and freed the icon.
func test_a_stop_shown_again_while_leaving_keeps_its_icon() -> void:
	var strip := RouteStrip.new()
	strip.size = Vector2(414.0, 16.0)
	add_child(strip)
	auto_free(strip)
	var stops: Array[RouteStop] = []
	for x: float in [0.0, 4.0, 8.0]:
		stops.append(RouteStop.at_point(Vector3(x, 0.0, 0.0)))
	var legs := PackedFloat32Array([4.0, 4.0])
	strip.show_route(stops, legs, -1.0, true)
	var icons := _icons(strip)

	strip.show_route(stops.slice(0, 2), legs.slice(0, 1), -1.0)
	await get_tree().process_frame
	strip.show_route(stops, legs, -1.0)
	await await_millis(int(RouteStrip.EXIT_SECONDS * 1000.0) + 200)

	assert_array(_icons(strip)).contains_exactly(icons)
	for icon: Control in icons:
		assert_float(icon.modulate.a).is_equal(1.0)


func test_the_x_on_a_stop_ahead_asks_to_remove_it() -> void:
	var strip := RouteStrip.new()
	strip.size = Vector2(414.0, 16.0)
	strip.position = Vector2(20.0, 20.0)
	strip.can_remove = func(_stop: RouteStop) -> bool: return true
	var runner := scene_runner(strip)
	var removed: Array[RouteStop] = []
	strip.remove_pressed.connect(func(stop: RouteStop) -> void: removed.append(stop))
	var stops: Array[RouteStop] = [
		RouteStop.at_point(Vector3.ZERO), RouteStop.at_point(Vector3(4.0, 0.0, 0.0))
	]
	strip.show_route(stops, PackedFloat32Array([4.0]), -1.0, true)
	var icons := _icons(strip)

	# The start offers none.
	runner.set_mouse_position(icons[0].get_global_rect().get_center())
	await runner.simulate_frames(1)
	assert_bool(_badge(icons[0]).visible).is_false()

	runner.set_mouse_position(icons[1].get_global_rect().get_center())
	await runner.simulate_frames(1)
	var badge := _badge(icons[1])
	assert_bool(badge.visible).is_true()
	# Moving onto the X keeps it up.
	runner.set_mouse_position(badge.get_global_rect().get_center())
	await runner.simulate_frames(1)
	assert_bool(badge.visible).is_true()

	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

	assert_array(removed).contains_exactly([stops[1]])


func _badge(icon: Control) -> RemoveBadge:
	for child: Node in icon.get_children():
		if child is RemoveBadge:
			return child as RemoveBadge
	return null


# The stops' icons: the strip's children that take the pointer.
func _icons(strip: RouteStrip) -> Array[Control]:
	var icons: Array[Control] = []
	for child: Node in strip.get_children():
		if child is Control and (child as Control).mouse_filter == Control.MOUSE_FILTER_PASS:
			icons.append(child as Control)
	return icons
