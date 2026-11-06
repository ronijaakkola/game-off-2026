extends Node3D
## The solar system. The pointer picks a planet, which shows its border, and a click plots
## the bus's course: to the planet under the pointer, or to the point on the orbit plane
## under it. Shift adds the stop to the end of the route; a right click cancels the course.

## How far past a planet's edge on screen, in pixels, the pointer still picks it, so a
## small, far planet stays easy to hit.
const PICK_MARGIN := 6.0
## The hover border's width on screen, in pixels at the base window height.
const OUTLINE_PIXELS := 3.0
const ORBIT_PLANE := Plane(Vector3.UP, 0.0)

var _planets: Array[Planet] = []


func _ready() -> void:
	_collect_planets(self)
	# Draws the border's material once while SceneFlow's fade covers the screen, so it
	# compiles now and not on the first hover. The first _process() clears it.
	for planet: Planet in _planets:
		planet.highlighted = true


func _process(_delta: float) -> void:
	var under := _planet_at(get_viewport().get_mouse_position())
	for planet: Planet in _planets:
		planet.highlighted = planet == under
	if under:
		under.outline_width = _pixels_to_world(OUTLINE_PIXELS, under.get_body_global_position())


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if not click or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		var stop := _stop_at(click.position)
		if not stop:
			return
		(%Bus as FrameshiftBus).plot_course(stop, click.shift_pressed)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		(%Bus as FrameshiftBus).cancel_course()
	else:
		return
	get_viewport().set_input_as_handled()


# The stop under screen_point: a planet, else the point on the orbit plane. Null when the
# pointer looks above the plane.
func _stop_at(screen_point: Vector2) -> RouteStop:
	var planet := _planet_at(screen_point)
	if planet:
		return RouteStop.at_planet(planet)
	var camera := %Camera as Camera3D
	var hit: Variant = ORBIT_PLANE.intersects_ray(
		camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point)
	)
	if hit == null:
		return null
	return RouteStop.at_point(hit)


# The nearest planet whose body covers screen_point on screen, give or take PICK_MARGIN.
func _planet_at(screen_point: Vector2) -> Planet:
	var camera := %Camera as Camera3D
	var best: Planet
	var best_depth := INF
	for planet: Planet in _planets:
		var center := planet.get_body_global_position()
		if camera.is_position_behind(center):
			continue
		var on_screen := camera.unproject_position(center)
		var edge := camera.unproject_position(
			center + camera.global_basis.x * planet.get_body_radius()
		)
		var reach := on_screen.distance_to(edge) + PICK_MARGIN
		var depth := camera.global_position.distance_to(center)
		if on_screen.distance_to(screen_point) <= reach and depth < best_depth:
			best = planet
			best_depth = depth
	return best


# How wide [param pixels] are in world units at [param point], seen through the camera.
func _pixels_to_world(pixels: float, point: Vector3) -> float:
	var camera := %Camera as Camera3D
	var depth := -(camera.global_transform.affine_inverse() * point).z
	var height := get_viewport().get_visible_rect().size.y
	return pixels * 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / height


func _collect_planets(node: Node) -> void:
	for child: Node in node.get_children():
		var planet := child as Planet
		if planet:
			_planets.append(planet)
		_collect_planets(child)
