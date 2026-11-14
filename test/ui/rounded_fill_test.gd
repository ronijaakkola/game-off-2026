extends GdUnitTestSuite

# A Frameshift key's cap: wide and short, with 8 px corners.
const RECT := Rect2(3.0, 3.0, 98.0, 35.0)
const RADIUS := 8.0


# A fill only a few pixels wide used to be a full-height strip with tiny corners, poking
# out past the button's rounded corners at both ends of the fill.
func test_a_thin_fill_stays_inside_the_rounded_corners() -> void:
	for fraction: float in [0.015, 0.03, 0.08, 0.5, 0.95, 0.99, 1.0]:
		var points := RoundedFill.outline(RECT, RADIUS, fraction)
		assert_int(points.size()).is_greater_equal(3)
		for point: Vector2 in points:
			(
				assert_bool(_inside(point))
				. override_failure_message(
					"%s at %s is outside the rounded shape" % [point, fraction]
				)
				. is_true()
			)


func test_a_thin_fill_is_shorter_than_the_button() -> void:
	var points := RoundedFill.outline(RECT, RADIUS, 0.02)
	var top := INF
	for point: Vector2 in points:
		top = minf(top, point.y)
	assert_float(top).is_greater(RECT.position.y + 1.0)


func test_the_fill_is_cut_straight_at_its_share() -> void:
	var right := -INF
	for point: Vector2 in RoundedFill.outline(RECT, RADIUS, 0.5):
		right = maxf(right, point.x)
	assert_float(right).is_equal_approx(RECT.position.x + RECT.size.x * 0.5, 0.01)


func test_nothing_shows_when_empty() -> void:
	assert_int(RoundedFill.outline(RECT, RADIUS, 0.0).size()).is_equal(0)


# Whether [param point] lies in the rounded box, give or take a hair.
func _inside(point: Vector2) -> bool:
	var inner := RECT.grow(-RADIUS)
	var nearest := point.clamp(inner.position, inner.end)
	return point.distance_to(nearest) <= RADIUS + 0.01


# The clip left a sliver of an edge by each end of the cut, and the soft edge folded over
# itself there, which showed as bright dots in the fill.
func test_no_edge_is_shorter_than_the_soft_edge_is_wide() -> void:
	for step: int in 1001:
		var points := RoundedFill.outline(RECT, RADIUS, step / 1000.0)
		for i: int in points.size():
			var length := points[i].distance_to(points[(i + 1) % points.size()])
			(
				assert_float(length)
				. override_failure_message("an edge %s long at %s" % [length, step / 1000.0])
				. is_greater_equal(RoundedFill.FEATHER)
			)
