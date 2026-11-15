class_name FlightTime
## How long the bus takes to fly a straight line, from its speeds and acceleration, and how
## far it flies along its route.


## Seconds to cover [param distance] in a straight line from [param start_speed], speeding
## up toward [param top] speed at [param acceleration] and braking to [param end_speed] at
## the end.
static func straight(
	distance: float, start_speed: float, end_speed: float, top: float, acceleration: float
) -> float:
	var speed_up := (top * top - start_speed * start_speed) / (2.0 * acceleration)
	var brake := (top * top - end_speed * end_speed) / (2.0 * acceleration)
	if speed_up + brake <= distance:
		var cruise := (distance - speed_up - brake) / top
		return (top - start_speed) / acceleration + cruise + (top - end_speed) / acceleration
	# Never reaches top speed: speeds up to a peak, then brakes.
	var ends := (start_speed * start_speed + end_speed * end_speed) * 0.5
	var peak := sqrt(maxf(acceleration * distance + ends, 0.0))
	if peak < start_speed:
		return maxf(start_speed - end_speed, 0.0) / acceleration
	return (peak - start_speed) / acceleration + maxf(peak - end_speed, 0.0) / acceleration


## How far the bus flies from [param from] along [param route] to its first planet, docking
## [param dock_gap] from its surface, on the orbit plane: along every stop when it has no
## planet.
static func to_first_planet(route: Array[RouteStop], from: Vector3, dock_gap: float) -> float:
	var at := Vector3(from.x, 0.0, from.z)
	var distance := 0.0
	for stop: RouteStop in route:
		var to := stop.get_target(at, dock_gap)
		distance += at.distance_to(to)
		at = to
		if stop.planet:
			break
	return distance
