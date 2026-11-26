extends GdUnitTestSuite
## The badge that points at the bus from the screen's edge while it is off screen: where
## it goes on the line toward the bus, and when it shows.

const SCENE := "res://game/solar_system/solar_system.tscn"
const PREVIEW := "res://test/previews/bus_indicator_preview.tscn"
const VIEW := Rect2(0.0, 0.0, 1152.0, 648.0)
# How far the badge's centre stays from the edge, and from a panel in its way.
const FROM_EDGE := BusIndicator.EDGE_GAP + BusIndicator.TIP
const FROM_PANEL := BusIndicator.PANEL_GAP + BusIndicator.TIP


func test_with_nothing_in_the_way_its_point_stops_short_of_the_edge() -> void:
	var at := BusIndicator.place_on_line(VIEW, Vector2.RIGHT, [])

	assert_vector(at).is_equal_approx(Vector2(VIEW.end.x - FROM_EDGE, 324.0), Vector2.ONE * 0.01)


func test_toward_a_corner_it_stays_inside_both_edges() -> void:
	var at := BusIndicator.place_on_line(VIEW, Vector2(1.0, 1.0).normalized(), [])

	# The screen is wider than tall, so the bottom edge stops it first.
	assert_float(at.y).is_equal_approx(VIEW.end.y - FROM_EDGE, 0.01)
	assert_float(at.x).is_less(VIEW.end.x - FROM_EDGE)


func test_a_panel_in_the_way_stops_it_short_of_the_panel() -> void:
	var panel := Rect2(876.0, 122.0, 264.0, 400.0)

	var at := BusIndicator.place_on_line(VIEW, Vector2.RIGHT, [panel])

	assert_vector(at).is_equal_approx(
		Vector2(panel.position.x - FROM_PANEL, 324.0), Vector2.ONE * 0.01
	)


func test_a_panel_the_disc_clears_is_passed() -> void:
	# The line runs under the panel, farther off than the disc but nearer than the whole
	# badge with its gap: it goes on to the edge rather than waiting by the panel.
	var clearance := BusIndicator.RADIUS + BusIndicator.PASS_GAP + 1.0
	var panel := Rect2(876.0, 122.0, 264.0, 324.0 - clearance - 122.0)

	var at := BusIndicator.place_on_line(VIEW, Vector2.RIGHT, [panel])

	assert_float(at.x).is_equal_approx(VIEW.end.x - FROM_EDGE, 0.01)


func test_a_panel_the_disc_would_touch_holds_it() -> void:
	var clearance := BusIndicator.RADIUS + BusIndicator.PASS_GAP - 1.0
	var panel := Rect2(876.0, 122.0, 264.0, 324.0 - clearance - 122.0)

	var at := BusIndicator.place_on_line(VIEW, Vector2.RIGHT, [panel])

	assert_float(at.x).is_equal_approx(panel.position.x - FROM_PANEL, 0.01)


func test_a_panel_behind_it_or_off_its_line_changes_nothing() -> void:
	var behind := Rect2(12.0, 12.0, 240.0, 600.0)
	var above := Rect2(437.0, 12.0, 277.0, 32.0)

	var at := BusIndicator.place_on_line(VIEW, Vector2.RIGHT, [behind, above])

	assert_float(at.x).is_equal_approx(VIEW.end.x - FROM_EDGE, 0.01)


func test_it_stays_down_while_the_bus_is_on_screen() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(5)

	assert_bool((runner.find_child("BusIndicator") as BusIndicator).is_showing()).is_false()


func test_it_shows_once_the_camera_leaves_the_bus_and_hides_while_the_bus_is_open() -> void:
	var runner := scene_runner(PREVIEW)
	await runner.simulate_frames(5)
	var indicator := runner.find_child("BusIndicator") as BusIndicator

	assert_bool(indicator.is_showing()).is_true()
	assert_float(indicator.modulate.a).is_greater(0.0)

	(runner.find_child("SolarSystem") as SolarSystem).open_bus()
	await runner.simulate_frames(2)

	assert_bool(indicator.is_showing()).is_false()
