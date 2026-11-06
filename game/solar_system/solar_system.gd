extends Node3D
## The solar system. The pointer picks a planet, which shows a white border, and a click
## plots the bus's course: to the planet under the pointer, or to the point on the orbit
## plane under it. Shift adds the stop to the end of the route; a right click cancels the
## course. Planets on the route show an orange border.
## It also runs the passengers: every time the bus docks, the passengers going to that
## planet get off and pay, and those waiting there board while seats are free. The game
## starts with one passenger on board.

## How far past a planet's edge on screen, in pixels, the pointer still picks it, so a
## small, far planet stays easy to hit.
const PICK_MARGIN := 6.0
## The border's width on screen, in pixels at the base window height.
const OUTLINE_PIXELS := 3.0
const ORBIT_PLANE := Plane(Vector3.UP, 0.0)

var _planets: Array[Planet] = []
var _credits := 0


func _ready() -> void:
	_collect_planets(self)
	# Draws the border's material once while SceneFlow's fade covers the screen, so it
	# compiles now and not on the first hover. The first _process() clears it.
	for planet: Planet in _planets:
		planet.border = Planet.Border.HOVER
	_start_passengers()


func _process(_delta: float) -> void:
	(%Cabin as Cabin).docked = (%Bus as FrameshiftBus).is_at_planet()
	var under := _planet_at(get_viewport().get_mouse_position())
	var on_route := (%Bus as FrameshiftBus).get_route_planets()
	for planet: Planet in _planets:
		if planet == under:
			planet.border = Planet.Border.HOVER
		elif planet in on_route:
			planet.border = Planet.Border.ROUTE
		else:
			planet.border = Planet.Border.NONE
		if planet.border != Planet.Border.NONE:
			planet.outline_width = _pixels_to_world(
				OUTLINE_PIXELS, planet.get_body_global_position()
			)


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


func _start_passengers() -> void:
	var bus := %Bus as FrameshiftBus
	var waiting := %WaitingPassengers as WaitingPassengers
	waiting.set_planets(_planets)
	bus.docked.connect(_on_bus_docked)
	var cabin := %Cabin as Cabin
	%PassengerPanel.set(&"cabin", cabin)
	var home := bus.get_docked_planet()
	if home:
		var first := waiting.create(home)
		if first:
			cabin.board(first)
	_show_credits()


func _on_bus_docked(planet: Planet) -> void:
	var cabin := %Cabin as Cabin
	_credits += cabin.arrive_at(planet)
	var free := cabin.seats - cabin.get_passengers().size()
	for passenger: Passenger in (%WaitingPassengers as WaitingPassengers).take(planet, free):
		cabin.board(passenger)
	_show_credits()


func _show_credits() -> void:
	(%CreditsLabel as Label).text = "%d credits" % _credits


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
