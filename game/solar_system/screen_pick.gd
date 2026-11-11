class_name ScreenPick
## What is under a point on screen, seen through a camera: something round in the world
## covers the point when it is within its radius on screen, give or take [constant MARGIN].
## No physics: the solar system has few things to pick and all of them are round.

## How far past an edge on screen, in pixels, the pointer still picks it, so a small, far
## planet stays easy to hit.
const MARGIN := 6.0


## Whether a sphere of [param radius] at [param center] covers [param screen_point] on
## screen, give or take [constant MARGIN]. False when it is behind [param camera].
static func covers(camera: Camera3D, center: Vector3, radius: float, screen_point: Vector2) -> bool:
	if camera.is_position_behind(center):
		return false
	var on_screen := camera.unproject_position(center)
	var edge := camera.unproject_position(center + camera.global_basis.x * radius)
	return on_screen.distance_to(screen_point) <= on_screen.distance_to(edge) + MARGIN


## The planet nearest [param camera] among [param planets] whose body covers
## [param screen_point] on screen, or null.
static func planet_at(camera: Camera3D, planets: Array[Planet], screen_point: Vector2) -> Planet:
	var best: Planet
	var best_depth := INF
	for planet: Planet in planets:
		var center := planet.get_body_global_position()
		if not covers(camera, center, planet.get_body_radius(), screen_point):
			continue
		var depth := camera.global_position.distance_to(center)
		if depth < best_depth:
			best = planet
			best_depth = depth
	return best


## The point in space among [param stops] whose diamond, [param size] across, covers
## [param screen_point] on screen. Where diamonds overlap, the one latest in the list. Null
## when there is none.
static func point_stop_at(
	camera: Camera3D, stops: Array[RouteStop], size: float, screen_point: Vector2
) -> RouteStop:
	for i: int in range(stops.size() - 1, -1, -1):
		var stop := stops[i]
		if not stop.planet and covers(camera, stop.point, size, screen_point):
			return stop
	return null
