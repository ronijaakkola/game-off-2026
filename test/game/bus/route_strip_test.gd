extends GdUnitTestSuite
## The route bar's line of stops.


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


# The stops' icons: the strip's children that take the pointer.
func _icons(strip: RouteStrip) -> Array[Control]:
	var icons: Array[Control] = []
	for child: Node in strip.get_children():
		if child is Control and (child as Control).mouse_filter == Control.MOUSE_FILTER_PASS:
			icons.append(child as Control)
	return icons
