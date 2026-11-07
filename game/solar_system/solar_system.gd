extends Node3D
## The solar system. The pointer picks a planet, which shows a white border, or else the
## diamond of the route's last stop when that is a point in space, which turns white. A
## right click adds a stop to the end of the bus's route: the planet under the pointer, or
## the point on the orbit plane under it. A right click on the route's last stop removes
## it, and the clear_route action clears the whole route. No modifier keys: Firefox opens
## its own context menu on Shift + right click whatever the page does. Left click is left
## free for selecting things. Planets on the route show an orange border. A hint at the
## bottom says how to set a course until the player first sets one.
## It also runs the passengers: every time the bus docks, the cabin runs a stop there,
## where the passengers going to that planet get off one by one and pay, and those waiting
## there board one by one while seats are free. The bus can't charge until the stop is
## over. The game starts with one passenger on board.

## How far past a planet's edge on screen, in pixels, the pointer still picks it, so a
## small, far planet stays easy to hit.
const PICK_MARGIN := 6.0
## The border's width on screen, in pixels at the base window height.
const OUTLINE_PIXELS := 3.0
## How tall a planet's name is on screen, in pixels at the base window height.
const LABEL_PIXELS := 13.0
## The gap between a planet's lower edge on screen and its name, in pixels.
const LABEL_GAP_PIXELS := 0.0
const ORBIT_PLANE := Plane(Vector3.UP, 0.0)

var _planets: Array[Planet] = []


func _ready() -> void:
	_collect_planets(self)
	# Draws the border's material once while SceneFlow's fade covers the screen, so it
	# compiles now and not on the first hover. The first _process() clears it.
	for planet: Planet in _planets:
		planet.border = Planet.Border.HOVER
	_start_passengers()


func _process(_delta: float) -> void:
	(%Cabin as Cabin).docked = (%Bus as FrameshiftBus).is_at_planet()
	_place_labels()
	var mouse := get_viewport().get_mouse_position()
	var under := _planet_at(mouse)
	var bus := %Bus as FrameshiftBus
	var marker: RouteStop = null if under else _marker_at(mouse)
	# Only the last stop, the one a right click removes.
	bus.hovered_stop = marker if marker and marker == bus.get_last_stop() else null
	var on_route := bus.get_route_planets()
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
	if event.is_action_pressed(&"clear_route"):
		(%Bus as FrameshiftBus).cancel_course()
		get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if not click or not click.pressed:
		return
	if click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var bus := %Bus as FrameshiftBus
	if _is_last_stop_at(click.position):
		bus.remove_last_stop()
	else:
		var stop := _stop_at(click.position)
		if not stop:
			return
		bus.plot_course(stop, true)
		(%CourseHint as Label).hide()
	get_viewport().set_input_as_handled()


func _start_passengers() -> void:
	var bus := %Bus as FrameshiftBus
	var waiting := %WaitingPassengers as WaitingPassengers
	waiting.set_planets(_planets)
	bus.docked.connect(_on_bus_docked)
	var cabin := %Cabin as Cabin
	cabin.delivered.connect(_on_delivered)
	cabin.unloaded.connect((%CreditsCounter as CreditsCounter).commit)
	cabin.stop_finished.connect(_on_stop_finished)
	var home := bus.get_docked_planet()
	if home:
		var first := waiting.create(home)
		if first:
			cabin.board(first)
	# After the first passenger boards, so their card is there from the start.
	(%PassengerPanel as PassengerPanel).cabin = cabin


func _on_bus_docked(planet: Planet) -> void:
	(%Bus as FrameshiftBus).boarding = true
	(%Cabin as Cabin).stop_at(planet, %WaitingPassengers as WaitingPassengers)


func _on_delivered(_passenger: Passenger, payout: int) -> void:
	(%CreditsCounter as CreditsCounter).add(payout)


func _on_stop_finished() -> void:
	(%Bus as FrameshiftBus).boarding = false


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


# Whether the route's last stop is under screen_point: its planet, or the diamond at its
# point in space when no planet is. The same pick as the hover, so what turns white is
# what a click removes.
func _is_last_stop_at(screen_point: Vector2) -> bool:
	var last := (%Bus as FrameshiftBus).get_last_stop()
	if not last:
		return false
	var planet := _planet_at(screen_point)
	if planet or last.planet:
		return planet != null and planet == last.planet
	return _marker_at(screen_point) == last


# The point in space on the route whose diamond covers screen_point on screen, give or take
# PICK_MARGIN. Where diamonds overlap, the one latest on the route, so the last stop can
# always be removed. Null when there is none.
func _marker_at(screen_point: Vector2) -> RouteStop:
	var bus := %Bus as FrameshiftBus
	var camera := %Camera as Camera3D
	var stops := bus.get_route_stops()
	stops.reverse()
	for stop: RouteStop in stops:
		if stop.planet or camera.is_position_behind(stop.point):
			continue
		var on_screen := camera.unproject_position(stop.point)
		var edge := camera.unproject_position(
			stop.point + camera.global_basis.x * bus.get_marker_size()
		)
		if on_screen.distance_to(screen_point) <= on_screen.distance_to(edge) + PICK_MARGIN:
			return stop
	return null


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


# Hangs each planet's name just under its body on screen, at the same size at any zoom.
func _place_labels() -> void:
	var camera := %Camera as Camera3D
	var height := get_viewport().get_visible_rect().size.y
	var pixel_size := (
		LABEL_PIXELS / height * 2.0 * tan(deg_to_rad(camera.fov) * 0.5) / Planet.LABEL_FONT_SIZE
	)
	var down := -camera.global_basis.y
	for planet: Planet in _planets:
		var gap := _pixels_to_world(LABEL_GAP_PIXELS, planet.get_body_global_position())
		planet.label_pixel_size = pixel_size
		planet.label_offset = down * (planet.get_body_radius() + gap)


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
