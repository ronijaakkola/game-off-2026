class_name SolarSystem
extends Node3D
## The solar system. The pointer picks a planet, which shows a white border, or else the
## diamond of the route's last stop when that is a point in space, which turns white; a
## pointer over the HUD picks nothing. A right click adds a stop to the end of the bus's
## route: the planet under the pointer, or the point on the orbit plane under it. A right
## click on the route's last stop removes it, and the clear_route action clears the whole
## route. No modifier keys: Firefox opens its own context menu on Shift + right click
## whatever the page does. Planets on the route show an orange border. A hint at the bottom
## says how to set a course until the player first sets one, hidden while a planet is open.
## A left click on a planet opens it: the camera follows it on the left side of the screen
## and its panel opens on the right. A left click on the open planet or on empty space, or
## the panel's close button, closes it, and the camera goes back to where it was. While a
## planet is open, the planets' names fade out, and the open planet's white hover border
## fades out and stays off; both fade back in when it closes.
## A left click on the bus opens it the same way, with its stats in its panel. One of the
## two is open at a time: opening either closes the other.
## It also runs the passengers: every time the bus docks, the cabin runs a stop there,
## where the passengers going to that planet get off one by one, pay and rate the ride,
## which goes into the average rating beside the credits, and earn a research point of
## their race, whatever their rating. Under each planet
## where someone waits, a small person and a number say how many. While the bus is docked
## or charging, the dock panel above the bus status lists who waits there, and the player
## picks them up one by one while seats are free; the row under the pointer, or a clicked
## one, shows their trip as an arc to their destination. The bus can't charge, and a
## charge under way holds, until the stop is over. The game starts with the bus empty.
## A passenger kicked off from their card is thrown out of the bus's door as a small figure
## in their skin colour.
## Docked at a planet that sells fuel, the player refuels there from the dock panel or its
## open planet's panel: the [FuelPump] runs while they hold the fuel button. It stops when
## they let go, the tank is full or the credits run out.
## Running out of fuel in space scares everyone on board ([constant OUT_OF_FUEL_SHOCK]),
## and the [TowOffer] bar offers a tow for [constant TOW_FEE] credits. Requesting it pays,
## into debt when the player has less, and a tow ship comes from the nearest planet and
## pulls the bus there, where it docks with a full tank.

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
## Seconds for the names and the open planet's hover border to fade out or back in.
const FADE_SECONDS := 0.4
## The process priority Phantom Camera's host sets on itself to move the camera, after
## everything it follows.
const CAMERA_HOST_PRIORITY := 300
## Pixels between a planet's name and the marker for who waits there.
const MARKER_GAP_PIXELS := 4.0
## What a tow costs, in credits.
const TOW_FEE := 100
## The goals a run starts with: deliver this many passengers, and keep this average rating.
const START_DELIVERIES := 30
const START_RATING := 4.0
## The scare everyone on board takes when the bus runs out of fuel in space.
const OUT_OF_FUEL_SHOCK := -15.0
const TOW_SHIP := preload("res://game/bus/tow_ship.tscn")
const KICKED_PASSENGER := preload("res://game/passengers/kicked_passenger.tscn")

var _planets: Array[Planet] = []
# The player's credits, research points and ratings. The resource bar shows them.
var _ledger := Ledger.new()
# 1 with no planet open, 0 once one is open and the fade is done.
var _fade := 1.0
# The planet whose hover border fades: the open one, and after it closes, until the fade
# is back to 1.
var _faded_planet: Planet


func _ready() -> void:
	# After the planets, the bus and the camera have moved this frame, so the names and
	# the waiting markers follow where they are now, not where they were a frame
	# ago. The camera moves last of those: Phantom Camera's host runs at priority 300.
	process_priority = CAMERA_HOST_PRIORITY + 1
	_collect_planets(self)
	# Draws the border's material once while SceneFlow's fade covers the screen, so it
	# compiles now and not on the first hover. The first _process() clears it.
	for planet: Planet in _planets:
		planet.border = Planet.Border.HOVER
	var studio := %PortraitStudio as PortraitStudio
	(%PassengerPanel as PassengerPanel).portrait_studio = studio
	(%PlanetPanel as PlanetPanel).portrait_studio = studio
	(%DockPanel as DockPanel).portrait_studio = studio
	_start_passengers()
	var panel := %PlanetPanel as PlanetPanel
	panel.waiting = %WaitingPassengers as WaitingPassengers
	panel.close_pressed.connect(close_planet)
	panel.slide_seconds = (%CameraRig as CameraRig).get_focus_seconds()
	var bus_panel := %BusPanel as BusPanel
	bus_panel.close_pressed.connect(close_bus)
	bus_panel.slide_seconds = panel.slide_seconds
	var markers := %WaitingMarkers as WaitingMarkers
	markers.waiting = %WaitingPassengers as WaitingPassengers
	markers.set_planets(_planets)
	var dock_panel := %DockPanel as DockPanel
	dock_panel.waiting = %WaitingPassengers as WaitingPassengers
	dock_panel.cabin = %Cabin as Cabin
	dock_panel.board_pressed.connect(_on_board_pressed)
	dock_panel.trip_previewed.connect((%TripArc as TripArc).show_passenger)
	dock_panel.research_pressed.connect(_on_research_pressed)
	var bus := %Bus as FrameshiftBus
	bus.ran_out_of_fuel.connect(_on_bus_ran_out_of_fuel)
	(%TowOffer as TowOffer).requested.connect(_on_tow_requested)


func _process(delta: float) -> void:
	(%Cabin as Cabin).docked = (%Bus as FrameshiftBus).is_at_planet()
	(%Cabin as Cabin).parking = (%Bus as FrameshiftBus).state == FrameshiftBus.State.PARKING
	var felt := (%Bus as FrameshiftBus).get_felt_acceleration()
	(%PortraitStudio as PortraitStudio).felt_acceleration = felt
	_place_labels()
	_update_fade(delta)
	_run_fuel_pump(delta)
	var rig := %CameraRig as CameraRig
	if rig.is_focused():
		rig.focus_rect = _focus_rect()
	var mouse := get_viewport().get_mouse_position()
	var over_hud := get_viewport().gui_get_hovered_control() != null
	# What a left click would open shows the white border.
	var picked: Node3D = null if over_hud else _pick_at(mouse)
	var under := picked as Planet
	_place_waiting()
	var bus := %Bus as FrameshiftBus
	var model := bus.get_model()
	model.border = picked == bus and not is_bus_open()
	if model.border:
		model.outline_width = _pixels_to_world(OUTLINE_PIXELS, bus.global_position)
	# A right click removes any point in space on the route.
	bus.hovered_stop = null if picked or over_hud else _marker_at(mouse)
	var on_route := bus.get_route_planets()
	for planet: Planet in _planets:
		var hover_opacity := _fade if planet == _faded_planet else 1.0
		if planet == under and hover_opacity > 0.0:
			planet.border = Planet.Border.HOVER
			planet.border_opacity = hover_opacity
		elif planet in on_route:
			planet.border = Planet.Border.ROUTE
			planet.border_opacity = 1.0
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
	if click.button_index == MOUSE_BUTTON_LEFT:
		_select_at(click.position)
		return
	if click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var bus := %Bus as FrameshiftBus
	var removed := _removable_stop_at(click.position)
	if removed:
		bus.remove_stop(removed)
	else:
		var stop := _stop_at(click.position)
		if not stop:
			return
		bus.plot_course(stop, true)
		(%CourseHint as Control).hide()
	get_viewport().set_input_as_handled()


## Opens [param planet]: the camera follows it on the left and its panel shows on the
## right. Opening another planet while one is open moves both on to it. It closes the bus's
## panel.
func open_planet(planet: Planet) -> void:
	if is_bus_open():
		(%BusPanel as BusPanel).close(true)
	(%PlanetPanel as PlanetPanel).open(planet)
	var rig := %CameraRig as CameraRig
	rig.focus_rect = _focus_rect()
	rig.focus(planet.get_body(), planet.get_body_radius(), planet.get_extent())


## Closes the open planet's panel and gives the camera back. Does nothing when none is open.
func close_planet() -> void:
	if not get_open_planet():
		return
	(%PlanetPanel as PlanetPanel).close()
	(%CameraRig as CameraRig).release_focus()


## The player's credits, research points and ratings.
func get_ledger() -> Ledger:
	return _ledger


## The open planet, or null.
func get_open_planet() -> Planet:
	return (%PlanetPanel as PlanetPanel).get_planet()


## Opens the bus: the camera follows it on the left and its panel shows its stats on the
## right. It closes the open planet's panel.
func open_bus() -> void:
	if get_open_planet():
		(%PlanetPanel as PlanetPanel).close(true)
	var bus := %Bus as FrameshiftBus
	(%BusPanel as BusPanel).open(bus)
	var rig := %CameraRig as CameraRig
	rig.focus_rect = _focus_rect()
	rig.focus(bus, FrameshiftBus.RADIUS, FrameshiftBus.RADIUS)


## Closes the bus's panel and gives the camera back. Does nothing when it isn't open.
func close_bus() -> void:
	if not is_bus_open():
		return
	(%BusPanel as BusPanel).close()
	(%CameraRig as CameraRig).release_focus()


func is_bus_open() -> bool:
	return (%BusPanel as BusPanel).is_open()


# A left click: on the bus or a planet opens it, on what is open or on empty space closes
# it.
func _select_at(screen_point: Vector2) -> void:
	var picked := _pick_at(screen_point)
	var planet := picked as Planet
	if picked is FrameshiftBus and not is_bus_open():
		open_bus()
	elif planet and planet != get_open_planet():
		open_planet(planet)
	elif get_open_planet():
		close_planet()
	elif is_bus_open():
		close_bus()
	else:
		return
	get_viewport().set_input_as_handled()


# Where the open planet or bus is framed: the space left of its panel.
func _focus_rect() -> Rect2:
	var screen := get_viewport().get_visible_rect().size
	var panel := (%BusPanel if is_bus_open() else %PlanetPanel) as SidePanel
	return Rect2(0.0, 0.0, screen.x - panel.get_width(), screen.y)


# Fades the names, and the open planet's hover border, out while a planet or the bus is
# open and back in after.
func _update_fade(delta: float) -> void:
	var open := get_open_planet()
	if open:
		_faded_planet = open
	var target := 0.0 if open or is_bus_open() else 1.0
	_fade = move_toward(_fade, target, delta / FADE_SECONDS)
	if _fade >= 1.0:
		_faded_planet = null
	for planet: Planet in _planets:
		planet.label_opacity = _fade


func _start_passengers() -> void:
	var bus := %Bus as FrameshiftBus
	var waiting := %WaitingPassengers as WaitingPassengers
	waiting.start(_planets, bus.get_docked_planet(), _ledger)
	bus.docked.connect(_on_bus_docked)
	var cabin := %Cabin as Cabin
	cabin.delivered.connect(_on_delivered)
	cabin.kicked.connect(_on_kicked)
	var bar := %ResourceBar as ResourceBar
	bar.ledger = _ledger
	var goals := %Goals as GoalTracker
	goals.ledger = _ledger
	goals.add(DeliveryCountGoal.new(START_DELIVERIES))
	goals.add(RatingGoal.new(START_RATING))
	var lab := %ResearchLab as ResearchLab
	lab.ledger = _ledger
	lab.planets = _planets
	cabin.unloaded.connect(bar.commit)
	cabin.stop_finished.connect(_on_stop_finished)
	(%PassengerPanel as PassengerPanel).cabin = cabin
	cabin.follow(bus.get_stats())


func _on_bus_docked(planet: Planet) -> void:
	(%Bus as FrameshiftBus).boarding = true
	(%Cabin as Cabin).stop_at(planet)


# The player picked up a passenger in the dock panel: they leave the line and board after
# whoever is getting off or on before them. Only at the planet the bus waits at, while a
# seat is free.
func _on_board_pressed(passenger: Passenger) -> void:
	var bus := %Bus as FrameshiftBus
	var cabin := %Cabin as Cabin
	var planet := bus.get_docked_planet()
	if not planet or not bus.is_at_planet() or cabin.get_free_seats() <= 0:
		return
	if not (%WaitingPassengers as WaitingPassengers).take(planet, passenger):
		return
	bus.boarding = true
	cabin.pick_up(passenger)


func _on_bus_ran_out_of_fuel() -> void:
	(%Cabin as Cabin).shock(OUT_OF_FUEL_SHOCK)
	(%TowOffer as TowOffer).offer(TOW_FEE)


# Bills the tow and sends a tow ship from the planet nearest to the bus, to tow it there.
func _on_tow_requested() -> void:
	(%TowOffer as TowOffer).close()
	_ledger.spend(TOW_FEE)
	var bus := %Bus as FrameshiftBus
	var nearest: Planet
	var nearest_distance := INF
	for planet: Planet in _planets:
		var distance := bus.global_position.distance_to(planet.get_body_global_position())
		if distance < nearest_distance:
			nearest = planet
			nearest_distance = distance
	if not nearest:
		return
	var ship := TOW_SHIP.instantiate() as TowShip
	add_child(ship)
	ship.hitched.connect(bus.tow_to.bind(nearest))
	ship.come_for(bus, nearest)


# Runs the fuel pump at the planet the bus is docked at while the dock panel's fuel
# button is held, or the open planet's refuel button when that is the same planet. Shows in
# both panels whether it can, and in the open planet's the fuel, the price and what stops it.
func _run_fuel_pump(delta: float) -> void:
	var bus := %Bus as FrameshiftBus
	var tank := bus.get_fuel_tank()
	var pump := %FuelPump as FuelPump
	var docked: Planet = bus.get_docked_planet() if bus.is_at_planet() else null
	var open := get_open_planet()
	var panel := %PlanetPanel as PlanetPanel
	var dock_panel := %DockPanel as DockPanel
	var stop := pump.get_stop(docked, tank, _ledger) if docked else ""
	var fill_cost := ceili((tank.capacity - tank.fuel) * docked.fuel_price) if docked else 0
	var can_fuel := docked != null and stop.is_empty()
	dock_panel.show_fuel(tank.get_fraction(), fill_cost, can_fuel, stop.trim_suffix("."))
	if docked:
		var held := dock_panel.is_fuel_held() or (open == docked and panel.is_refuel_held())
		pump.run(delta, docked, held, tank, _ledger)
	else:
		pump.stop(_ledger)
	if not open:
		return
	var open_stop := stop if open == docked else "Dock here to refuel."
	if not open.sells_fuel:
		open_stop = "No fuel sold here."
	var note := open_stop if open_stop else "%d credits" % _ledger.credits
	var full_tank_cost := ceili(tank.capacity * open.fuel_price)
	panel.show_fuel(tank.get_fraction(), full_tank_cost, open_stop.is_empty(), note)


# The dock panel's Research button: opens the planet on its Research tab.
func _on_research_pressed(planet: Planet) -> void:
	open_planet(planet)
	(%PlanetPanel as PlanetPanel).show_tab(PlanetPanel.RESEARCH_TAB)


func _on_delivered(passenger: Passenger, payout: int) -> void:
	_ledger.earn(payout)
	_ledger.rate(passenger.get_rating())
	_ledger.earn_research(passenger.race)


func _on_kicked(passenger: Passenger) -> void:
	var bus := %Bus as FrameshiftBus
	var figure := KICKED_PASSENGER.instantiate() as KickedPassenger
	add_child(figure)
	var door := bus.global_transform * FrameshiftBus.DOOR
	figure.throw(door, -bus.global_basis.x.normalized(), passenger.look.skin_color)


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


# The stop on the route a right click at screen_point removes, or null: the last stop
# when it is the planet there, or else any point in space whose diamond is there. A planet
# earlier on the route isn't removed, so a route can come back to it. The same pick as the
# hover, so what turns white is what a click removes.
func _removable_stop_at(screen_point: Vector2) -> RouteStop:
	var planet := _planet_at(screen_point)
	if planet:
		var last := (%Bus as FrameshiftBus).get_last_stop()
		return last if last and last.planet == planet else null
	return _marker_at(screen_point)


# The point in space on the route whose diamond covers screen_point on screen, give or take
# PICK_MARGIN. Where diamonds overlap, the one latest on the route. Null when there is
# none.
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


# What a left click at screen_point opens: the bus, a planet, or null. Where the bus and a
# planet overlap, as when it is docked, whichever centre is nearer wins, so the docked
# planet stays easy to open.
func _pick_at(screen_point: Vector2) -> Node3D:
	var planet := _planet_at(screen_point)
	if not _is_bus_at(screen_point):
		return planet
	var bus := %Bus as FrameshiftBus
	if not planet:
		return bus
	var camera := %Camera as Camera3D
	var to_bus := screen_point.distance_to(camera.unproject_position(bus.global_position))
	var to_planet := screen_point.distance_to(
		camera.unproject_position(planet.get_body_global_position())
	)
	return bus if to_bus < to_planet else planet


# Whether the bus covers screen_point on screen, give or take PICK_MARGIN.
func _is_bus_at(screen_point: Vector2) -> bool:
	var camera := %Camera as Camera3D
	var center := (%Bus as FrameshiftBus).global_position
	if camera.is_position_behind(center):
		return false
	var on_screen := camera.unproject_position(center)
	var edge := camera.unproject_position(center + camera.global_basis.x * FrameshiftBus.RADIUS)
	return on_screen.distance_to(screen_point) <= on_screen.distance_to(edge) + PICK_MARGIN


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


# Shows the dock panel for the planet the bus waits at, docked or charging, and puts each
# planet's waiting marker under its name, while the bus has the waiting markers trait. The
# markers and the fuel forecast fade with the names.
func _place_waiting() -> void:
	var bus := %Bus as FrameshiftBus
	var camera := %Camera as Camera3D
	(%DockPanel as DockPanel).planet = bus.get_docked_planet() if bus.is_at_planet() else null
	var markers := %WaitingMarkers as WaitingMarkers
	markers.modulate.a = _fade
	(%FuelForecast as Control).modulate.a = _fade
	(%TripArc as TripArc).opacity = _fade
	var unlocked := bus.get_stats().get_traits().has(BusTraits.Type.WAITING_MARKERS)
	var below := LABEL_PIXELS + MARKER_GAP_PIXELS
	for planet: Planet in _planets:
		var center := planet.get_body_global_position()
		if camera.is_position_behind(center):
			markers.place(planet, Vector2.ZERO, false)
			continue
		var bottom := camera.unproject_position(
			center - camera.global_basis.y * planet.get_body_radius()
		)
		markers.place(planet, bottom + Vector2(0.0, below), unlocked and _fade > 0.0)


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
