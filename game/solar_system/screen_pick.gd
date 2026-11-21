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
## [param screen_point] on screen, or null. A hidden planet covers nothing.
static func planet_at(camera: Camera3D, planets: Array[Planet], screen_point: Vector2) -> Planet:
	var best: Planet
	var best_depth := INF
	for planet: Planet in planets:
		if not planet.is_visible_in_tree():
			continue
		var center := planet.get_body_global_position()
		if not covers(camera, center, planet.get_body_radius(), screen_point):
			continue
		var depth := camera.global_position.distance_to(center)
		if depth < best_depth:
			best = planet
			best_depth = depth
	return best


## What a click at [param screen_point] picks: [param bus] where it covers the point, else
## [param planet], the planet there or null. Where both cover it, as when the bus is
## docked, whichever centre is nearer the point wins, so the docked planet stays easy to
## pick.
static func bus_or_planet_at(
	camera: Camera3D, bus: FrameshiftBus, planet: Planet, screen_point: Vector2
) -> Node3D:
	if not covers(camera, bus.global_position, FrameshiftBus.RADIUS, screen_point):
		return planet
	if not planet:
		return bus
	var to_bus := screen_point.distance_to(camera.unproject_position(bus.global_position))
	var to_planet := screen_point.distance_to(
		camera.unproject_position(planet.get_body_global_position())
	)
	return bus if to_bus < to_planet else planet


## The square on screen around a sphere of [param radius] at [param center], seen through
## [param camera].
static func square_around(camera: Camera3D, center: Vector3, radius: float) -> Rect2:
	var on_screen := camera.unproject_position(center)
	var edge := camera.unproject_position(center + camera.global_basis.x * radius)
	var size := on_screen.distance_to(edge)
	return Rect2(on_screen - Vector2.ONE * size, Vector2.ONE * size * 2.0)
