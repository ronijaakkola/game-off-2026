extends Node
## A test map for the asteroid field: the solar system with an [AsteroidField] round the
## star, between Giant and Frost, with Frost moved out to make room. Play it as the game
## (F6 in the editor): three commuters going to Frost are on board, so the bumps show in
## their happiness, and "Rough ride!" shows over the bus as it flies into the rocks.
## `-- Rocks` sends the bus from Ember straight into the rocks, with the camera on it;
## `-- Gap` sends it out along a gap instead. Either takes 12 to 20 s to get there
## (`capture <this scene> --frames 1000 -- Rocks`). `-- Hover` rests the pointer on the belt,
## so its tooltip shows.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const ALERT := preload("res://game/solar_system/icons/triangle_alert.svg")
## Where Frost orbits here, out past the belt: 17.5 in the game's own solar system.
const FROST_ORBIT := 21.0
const ROUGH_RIDE := "Rough ride!"


func _ready() -> void:
	var system := %SolarSystem as SolarSystem
	var field := %AsteroidField as AsteroidField
	var bus := system.find_child("Bus") as FrameshiftBus
	var cabin := system.find_child("Cabin") as Cabin
	var frost := system.find_child("Frost") as Planet
	frost.orbit_radius = FROST_ORBIT
	field.bus = bus
	field.cabin = cabin
	field.orbit_clock = system.find_child("OrbitClock") as OrbitClock
	var quick := system.find_child("BusQuickText") as BusQuickText
	field.entered_rocks.connect(
		func() -> void: quick.show_text(ROUGH_RIDE, ALERT, BusQuickText.Kind.LOSS)
	)
	for i: int in 3:
		cabin.board(Passenger.new(COMMUTER, frost, 60.0, 40.0))
	var args := OS.get_cmdline_user_args()
	if "Rocks" in args or "Gap" in args:
		_send_out(system, field, bus, "Gap" in args)
	if "Hover" in args:
		_hover(field)


# Moves the pointer onto the belt, at the spot of it nearest the middle of the screen.
func _hover(field: AsteroidField) -> void:
	await get_tree().create_timer(0.2).timeout
	var camera := get_viewport().get_camera_3d()
	var middle := get_viewport().get_visible_rect().get_center()
	var radius := (field.belt.inner_radius + field.belt.outer_radius) * 0.5
	var nearest := Vector2.INF
	for degrees: int in range(0, 360, 5):
		var spot := field.to_global(AsteroidBelt.get_gap_direction(degrees) * radius)
		var on_screen := camera.unproject_position(spot)
		if on_screen.distance_to(middle) < nearest.distance_to(middle):
			nearest = on_screen
	var motion := InputEventMouseMotion.new()
	motion.position = nearest
	motion.global_position = nearest
	Input.parse_input_event(motion)


# Sends the bus from where it is docked out across the belt: through the rocks halfway
# between the two gaps either side of it, or into the nearest gap and straight along it,
# leading it as it turns. The camera follows the bus.
func _send_out(system: SolarSystem, field: AsteroidField, bus: FrameshiftBus, gap: bool) -> void:
	var belt := field.belt
	var local := field.to_local(bus.global_position)
	var bus_angle := rad_to_deg(atan2(-local.z, local.x))
	var gaps := belt.gap_angles.duplicate()
	gaps.sort_custom(
		func(a: float, b: float) -> bool:
			return wrapf(a - bus_angle, 0.0, 360.0) < wrapf(b - bus_angle, 0.0, 360.0)
	)
	# The gaps either side of the bus: the first ahead of it, counter-clockwise, and the last.
	var ahead: float = gaps[0]
	var behind: float = gaps[gaps.size() - 1]
	var angle := behind + wrapf(ahead - behind, 0.0, 360.0) * 0.5
	if gap:
		var to_ahead := wrapf(ahead - bus_angle, 0.0, 360.0)
		angle = ahead if to_ahead < 360.0 - to_ahead else behind
	var inner := AsteroidBelt.get_gap_direction(angle) * (belt.inner_radius - 1.0)
	var outer := AsteroidBelt.get_gap_direction(angle) * (belt.outer_radius + 1.5)
	# Lead the belt's turn: about 2 s of charge, then the flight at full speed.
	var to_inner := 2.0 + inner.distance_to(local) / bus.max_speed
	var to_outer := to_inner + inner.distance_to(outer) / bus.max_speed
	var turn := TAU / field.orbit_period
	var inner_at := field.global_transform * inner.rotated(Vector3.UP, turn * to_inner)
	var outer_at := field.global_transform * outer.rotated(Vector3.UP, turn * to_outer)
	if gap:
		bus.plot_course(RouteStop.at_point(inner_at))
		bus.plot_course(RouteStop.at_point(outer_at), true)
	else:
		bus.plot_course(RouteStop.at_point(outer_at))
	bus.frameshift_held = true
	system.open_bus()
