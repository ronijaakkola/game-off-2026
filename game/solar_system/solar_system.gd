class_name SolarSystem
extends Node3D
## The solar system. The pointer picks a planet, which shows a white border, or else the
## diamond of the route's last stop when that is a point in space, which turns white; a
## pointer over the HUD picks nothing. A right click adds a stop to the end of the bus's
## route: the planet under the pointer, or the point on the orbit plane under it. A right
## click on the route's last stop removes it, and the clear_route action clears the whole
## route. No modifier keys: Firefox opens its own context menu on Shift + right click
## whatever the page does. Planets on the route show an orange border.
## A new run from the main menu starts with the [Tutorial], on the map zoomed in on Terra
## and the Moon ([MapZoom]); once it is over, the map zooms out to the whole solar system,
## and only then do the other planets' lines start, the goals come and the run saves. A run
## without it shows a tutorial notice on how to set a course until the player first sets
## one.
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
## their race, whatever their rating. Under each planet's name, dots say how many wait
## there ([WaitingMarkers]), and a badge on its rim says it has a lab ([LabBadges]). While
## the bus is docked
## or charging, the dock panel above the bus status lists who waits there, and the player
## picks them up one by one while seats are free; the row under the pointer, or a clicked
## one, shows their trip as an arc to their destination. The bus can't charge, and a
## charge under way holds, until the stop is over. The game starts with the bus empty.
## A passenger kicked off from their card is thrown out of the bus's door as a small figure
## in their skin colour.
## Docked at a planet that sells fuel, the player refuels there from the dock panel or its
## open planet's panel ([FuelPump]).
## Running out of fuel in space brings the [TowDispatch].
## How fast the planets orbit is the [OrbitClock]'s.

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
## The goals a run starts with: deliver this many passengers, and keep this average rating.
const START_DELIVERIES := 30
const START_RATING := 3.5
const COURSE_HINT := "Right-click planets or space to add stops. Backspace clears the route."
const MAP_OPENED := "The whole solar system is open. Deliver passengers to get promotion."
## Seconds the notice that the map is open shows.
const MAP_OPENED_SECONDS := 8.0
## The user argument that starts the scene with the tutorial, as a new run from the main
## menu does: [code]capture <scene> -- --tutorial[/code].
const TUTORIAL_ARG := "--tutorial"
const KICKED_PASSENGER := preload("res://game/passengers/kicked_passenger.tscn")

var _planets: Array[Planet] = []
# The player's credits, research points and ratings. The resource bar shows them.
var _ledger := Ledger.new()
# 1 with no planet open, 0 once one is open and the fade is done.
var _fade := 1.0
# The planet whose hover border fades: the open one, and after it closes, until the fade
# is back to 1.
var _faded_planet: Planet
# How to set a course, until the player first sets one.
var _course_hint: Notice


# Before the planets, the bus and the camera are ready, so a continued run starts where it
# was saved, and the tutorial on the zoomed map.
func _enter_tree() -> void:
	if not _planets.is_empty():
		return
	_collect_planets(self)
	var saver := %GameSaver as GameSaver
	saver.place_world(_planets, _ledger)
	if saver.is_new_run() or TUTORIAL_ARG in OS.get_cmdline_user_args():
		(%MapZoom as MapZoom).zoom_in()
		saver.holding = true


func _ready() -> void:
	# After the planets, the bus and the camera have moved this frame, so the names and
	# the waiting markers follow where they are now, not where they were a frame
	# ago. The camera moves last of those: Phantom Camera's host runs at priority 300.
	process_priority = CAMERA_HOST_PRIORITY + 1
	(%OrbitClock as OrbitClock).start(_planets)
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
	markers.portrait_studio = studio
	markers.set_planets(_planets)
	(%LabBadges as LabBadges).set_planets(_planets)
	var dock_panel := %DockPanel as DockPanel
	dock_panel.waiting = %WaitingPassengers as WaitingPassengers
	dock_panel.cabin = %Cabin as Cabin
	dock_panel.board_pressed.connect(_on_board_pressed)
	dock_panel.trip_previewed.connect((%TripArc as TripArc).show_passenger)
	dock_panel.research_pressed.connect(_on_research_pressed)
	var tow := %TowDispatch as TowDispatch
	tow.ledger = _ledger
	tow.planets = _planets
	var zoom := %MapZoom as MapZoom
	if zoom.is_zoomed():
		(%Tutorial as Tutorial).finished.connect(_on_tutorial_finished)
		zoom.zoomed_out.connect(_on_map_zoomed_out)
		(%Tutorial as Tutorial).waiting = %WaitingPassengers as WaitingPassengers
		(%Tutorial as Tutorial).start()
	# A continued run has set courses before.
	elif not (%GameSaver as GameSaver).is_continued():
		_course_hint = (%Notices as NoticeStack).push(COURSE_HINT, Notice.Kind.TUTORIAL)


func _process(delta: float) -> void:
	(%OrbitClock as OrbitClock).run(delta)
	(%Cabin as Cabin).docked = (%Bus as FrameshiftBus).is_at_planet()
	(%Cabin as Cabin).parking = (%Bus as FrameshiftBus).state == FrameshiftBus.State.PARKING
	var felt := (%Bus as FrameshiftBus).get_felt_acceleration()
	(%PortraitStudio as PortraitStudio).felt_acceleration = felt
	_place_labels()
	_update_fade(delta)
	var rig := %CameraRig as CameraRig
	if rig.is_focused():
		rig.focus_rect = _focus_rect()
	var mouse := get_viewport().get_mouse_position()
	var over_hud := get_viewport().gui_get_hovered_control() != null
	# What a left click would open shows the white border.
	var picked: Node3D = null if over_hud else _pick_at(mouse)
	var under := picked as Planet
	_place_waiting(under)
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
	if (%MapZoom as MapZoom).is_zooming_out():
		return
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
		if not stop or not (%Tutorial as Tutorial).allows_course():
			return
		bus.plot_course(stop, true)
		if _course_hint:
			_course_hint.dismiss()
			_course_hint = null
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
	if not (%MapZoom as MapZoom).is_zoomed():
		_add_goals()
	var lab := %ResearchLab as ResearchLab
	lab.ledger = _ledger
	cabin.unloaded.connect(bar.commit)
	cabin.stop_finished.connect(_on_stop_finished)
	(%PassengerPanel as PassengerPanel).cabin = cabin
	cabin.follow(bus.get_stats())
	(%FuelPump as FuelPump).ledger = _ledger
	var saver := %GameSaver as GameSaver
	saver.waiting = waiting
	saver.start()


# The run's goals, and from here on passengers call with quests.
func _add_goals() -> void:
	var goals := %Goals as GoalTracker
	goals.add(DeliveryCountGoal.new(START_DELIVERIES))
	goals.add(RatingGoal.new(START_RATING))
	var waiting := %WaitingPassengers as WaitingPassengers
	(%QuestGiver as QuestGiver).start(_planets, _ledger, waiting)


# The tutorial is over: whatever is open closes, and the map zooms out.
func _on_tutorial_finished() -> void:
	close_planet()
	close_bus()
	(%MapZoom as MapZoom).zoom_out()


# The run proper starts on the whole map: every planet's line, the goals, and saving.
func _on_map_zoomed_out() -> void:
	var waiting := %WaitingPassengers as WaitingPassengers
	waiting.set_planets(_planets)
	waiting.add_starting_passengers((%Bus as FrameshiftBus).get_docked_planet())
	_add_goals()
	(%GameSaver as GameSaver).holding = false
	(%Notices as NoticeStack).push(MAP_OPENED, Notice.Kind.INFO, false, MAP_OPENED_SECONDS)


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


# The dock panel's Research button: opens the research screen on every tree.
func _on_research_pressed(_planet: Planet) -> void:
	(%ResearchLab as ResearchLab).open_screen()


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


# The point in space on the route whose diamond covers screen_point on screen. Where
# diamonds overlap, the one latest on the route. Null when there is none.
func _marker_at(screen_point: Vector2) -> RouteStop:
	var bus := %Bus as FrameshiftBus
	return ScreenPick.point_stop_at(
		%Camera as Camera3D, bus.get_route_stops(), bus.get_marker_size(), screen_point
	)


# What a left click at screen_point opens: the bus, a planet, or null. Where the bus and a
# planet overlap, as when it is docked, whichever centre is nearer wins, so the docked
# planet stays easy to open.
func _pick_at(screen_point: Vector2) -> Node3D:
	var planet := _planet_at(screen_point)
	var bus := %Bus as FrameshiftBus
	var camera := %Camera as Camera3D
	if not ScreenPick.covers(camera, bus.global_position, FrameshiftBus.RADIUS, screen_point):
		return planet
	if not planet:
		return bus
	var to_bus := screen_point.distance_to(camera.unproject_position(bus.global_position))
	var to_planet := screen_point.distance_to(
		camera.unproject_position(planet.get_body_global_position())
	)
	return bus if to_bus < to_planet else planet


func _planet_at(screen_point: Vector2) -> Planet:
	return ScreenPick.planet_at(%Camera as Camera3D, _get_shown_planets(), screen_point)


# The planets on the map: all of them, but only Terra and the Moon while it is zoomed in.
func _get_shown_planets() -> Array[Planet]:
	var shown: Array[Planet] = []
	shown.assign(_planets.filter(func(planet: Planet) -> bool: return planet.is_visible_in_tree()))
	return shown


# Shows the dock panel for the planet the bus waits at, docked or charging, and tells the
# waiting markers and the lab badges which planet is under the pointer. The markers, lab
# badges and the fuel forecast fade with the names.
func _place_waiting(under: Planet) -> void:
	var bus := %Bus as FrameshiftBus
	(%DockPanel as DockPanel).planet = bus.get_docked_planet() if bus.is_at_planet() else null
	var markers := %WaitingMarkers as WaitingMarkers
	markers.modulate.a = _fade
	markers.hovered = under
	var badges := %LabBadges as LabBadges
	badges.modulate.a = _fade
	badges.hovered = under
	(%FuelForecast as Control).modulate.a = _fade
	(%TripArc as TripArc).opacity = _fade


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
