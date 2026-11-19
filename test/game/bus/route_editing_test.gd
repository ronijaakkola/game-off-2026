extends GdUnitTestSuite
## How adding and removing a stop changes the route.

var _a: Planet
var _b: Planet
var _c: Planet


func before_test() -> void:
	_a = auto_free(Planet.new()) as Planet
	_b = auto_free(Planet.new()) as Planet
	_c = auto_free(Planet.new()) as Planet


func test_adding_the_planet_the_route_ends_at_does_nothing() -> void:
	var route := _route([_a])
	RouteEditing.add(route, RouteStop.at_planet(_a))
	RouteEditing.add(route, RouteStop.at_planet(_b))
	assert_array(_planets(route)).contains_exactly([_a, _b])


func test_a_planet_in_the_middle_goes_with_the_points_before_it() -> void:
	var route := _route([_a, Vector3.ONE, _b, _c])
	RouteEditing.remove(route, route[2])
	assert_array(_planets(route)).contains_exactly([_a, _c])
	assert_array(route).has_size(2)


func test_the_last_point_goes_alone() -> void:
	var route := _route([_a, _b, Vector3.ONE])
	RouteEditing.remove(route, route[2])
	assert_array(_planets(route)).contains_exactly([_a, _b])


func test_the_same_planet_left_side_by_side_becomes_one() -> void:
	var route := _route([_a, _b, _a])
	RouteEditing.remove(route, route[1])
	assert_array(_planets(route)).contains_exactly([_a])


func test_a_first_stop_at_the_docked_planet_goes_too() -> void:
	var route := _route([_b, _a, _c])
	RouteEditing.remove(route, route[0], _a)
	assert_array(_planets(route)).contains_exactly([_c])


func test_a_stop_not_on_the_route_changes_nothing() -> void:
	var route := _route([_a, _b])
	RouteEditing.remove(route, RouteStop.at_planet(_a))
	assert_array(route).has_size(2)


# A route of planets, and points in space for the Vector3s.
func _route(stops: Array) -> Array[RouteStop]:
	var route: Array[RouteStop] = []
	for stop: Variant in stops:
		route.append(
			RouteStop.at_planet(stop as Planet) if stop is Planet else RouteStop.at_point(stop)
		)
	return route


func _planets(route: Array[RouteStop]) -> Array[Planet]:
	var planets: Array[Planet] = []
	for stop: RouteStop in route:
		if stop.planet:
			planets.append(stop.planet)
	return planets
