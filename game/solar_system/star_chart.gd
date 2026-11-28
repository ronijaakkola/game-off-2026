class_name StarChart
extends Node
## The map pulled back until the star systems the bus has been to show as stars alone, in
## plain space. [method open] closes the open planet's or the bus's panel, then draws the
## camera back from where it is to over the middle of those stars, zooming out by the same
## factor in every equal step as the tutorial's zoom out does. On the way the orbit lines
## fade, the planets shrink where they are until they are gone, as do the rocks and
## whatever else orbits the star, and the capsules hide then. The bus's model glides from
## the bus to beside its star, wherever the bus is, growing as the camera rises, so it ends
## a little smaller on screen than it is in play. The heat zone's glow fades, and the sky
## goes from the system's colours to plain ones. The other systems show as their stars from
## the start, and come into view as the camera rises. [method close] plays it back. The HUD
## stays, and takes no clicks but on the notices and the pause button while the chart is
## open, as pan and zoom wait. Under Reduce motion both cut.
## Open, the bus can go to another star ([method travel]): its model flies there over the
## chart, and the chart then closes into that star's system.

## The camera is over the stars.
signal opened
## The map is as it was, and the camera is the player's.
signal closed

## The debug panel's button, which opens it and, once open, closes it again.
const DEBUG_OPEN_TEXT := "Open star chart"
const DEBUG_CLOSE_TEXT := "Close star chart"

@export var star_map: StarMap
@export var rig: CameraRig
@export var sky: SpaceSky
@export var hud: HudLayout
## Close as the chart opens.
@export var planet_panel: PlanetPanel
@export var bus_panel: BusPanel
@export var heat_zone: HeatZone
## Its model shows on the chart, beside the star of the system the bus is in.
@export var bus: FrameshiftBus
## How far from its star's centre the bus's model sits on the chart, on the side the bus
## is on.
@export_range(0.0, 50.0, 0.1) var bus_star_distance := 6.5
## Hides once the planets are gone.
@export var capsules: Node3D
## How far back the camera ends.
@export_range(1.0, 400.0, 0.1, "or_greater") var chart_distance := 150.0
## How big the bus is on the chart, as a share of how big it looks in play from
## [member bus_view_distance] back, wherever on the chart it is.
@export_range(0.1, 2.0, 0.05) var bus_size := 0.9
@export_range(1.0, 400.0, 0.1, "or_greater") var bus_view_distance := 45.0
## Seconds the pull back takes.
@export_range(0.1, 20.0, 0.1) var open_seconds := 2.0
## Seconds the way back in takes.
@export_range(0.1, 20.0, 0.1) var close_seconds := 1.5
## Seconds the bus's model takes to fly from one star to another.
@export_range(0.1, 20.0, 0.1) var travel_seconds := 1.8

@export_group("Timing")
## How far through the pull back the orbit lines are gone, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var orbits_gone := 0.4
## How far through it the planets start to shrink, and are gone.
@export_range(0.0, 1.0, 0.01) var planets_shrink := 0.2
@export_range(0.0, 1.0, 0.01) var planets_gone := 0.75
## How far through it the sky starts to lose the system's colours. Plain at the end.
@export_range(0.0, 1.0, 0.01) var sky_fades := 0.25

@export_group("Plain sky")
## The [SpaceSky]'s colours over the stars, which belong to no system.
@export var background_color := Color(0.02, 0.022, 0.045)
@export var fog_color := Color(0.03, 0.05, 0.11)
@export var fog_accent_color := Color(0.06, 0.035, 0.08)
@export var sky_star_color := Color(0.9, 0.95, 1.0)

# Whether it is open, opening or closing.
var _in_use := false
var _motion: Tween
# The camera as it was, to pull back from and to put back.
var _from := Vector3.ZERO
var _from_distance := 0.0
var _max_distance := 0.0
var _bounds_center := Vector3.ZERO
var _bounds_radius := 0.0
# Where the camera ends: over the middle of the stars.
var _to := Vector3.ZERO
# The sky's colours as they were: background, fog, accent and stars.
var _sky_colors: Array[Color] = []
# The systems on the chart, and whether each showed on the map.
var _systems: Dictionary[StarSystem, bool] = {}
# What orbits those systems' stars and showed on the map, with the capsules.
var _contents: Array[Node3D] = []
var _planets: Array[Planet] = []
# How far the pull back has got, from 0 to 1.
var _progress := 0.0
# Where the bus's model flies from on its way to another star, and how far it has got,
# from 0 to 1. Not finite while it stays beside its star.
var _travel_from := Vector3.INF
var _travel := 1.0
# Null with the debug panel off.
var _debug_button: Button


func _ready() -> void:
	_debug_button = DebugPanel.add_button(
		DEBUG_OPEN_TEXT, _debug_toggle, self, Progression.DEBUG_GROUP
	)


## Whether the chart is open, opening or closing.
func is_open() -> bool:
	return _in_use


## Pulls the camera back over the stars ([signal opened] once there), closing the open
## planet's or the bus's panel, over [member open_seconds] or, when given, [param seconds].
## Does nothing while it is in use.
func open(seconds := 0.0) -> void:
	if _in_use:
		return
	_in_use = true
	if planet_panel.get_planet():
		planet_panel.close()
	if bus_panel.is_open():
		bus_panel.close()
	rig.release_focus()
	rig.locked = true
	hud.cover()
	_remember()
	if Settings.reduce_motion:
		_step(1.0)
	else:
		_tween_step(0.0, 1.0, seconds if seconds > 0.0 else open_seconds)
		await _motion.finished
	opened.emit()


## Brings the camera back to where it was ([signal closed] once there).
## Does nothing unless it is open and still.
func close() -> void:
	if not _in_use or _systems.is_empty() or (_motion and _motion.is_running()):
		return
	if Settings.reduce_motion:
		_step(0.0)
	else:
		_tween_step(1.0, 0.0, close_seconds)
		await _motion.finished
	_restore()
	rig.locked = false
	_in_use = false
	if _debug_button:
		_debug_button.text = DEBUG_OPEN_TEXT
	hud.uncover()
	closed.emit()


## How far the pull back has got, from 0 (the map) to 1 (the chart).
func get_progress() -> float:
	return _progress


## Whether the chart is open with nothing moving, so the bus can go to another star.
func is_still() -> bool:
	return _in_use and _progress >= 1.0 and not (_motion and _motion.is_running())


## The bus goes to another star while the chart is open and still. [param enter] makes that
## star's system the one the bus works in and puts the bus there; the chart is then that
## system's, and the bus's model flies from beside the star it left to beside the new one.
## It returns once the model is there; [method close] then closes into the new system.
func travel(enter: Callable) -> void:
	if not is_still():
		return
	var from := bus.get_model().global_position
	# The map as it was, so the chart can keep the new system's in its place.
	_step(0.0)
	_restore()
	enter.call()
	rig.move_to(star_map.get_current().position)
	# Within what the new system lets the camera zoom out to, at once.
	rig.set_distance(rig.distance)
	_remember()
	_travel_from = from
	_travel = 0.0
	_step(1.0)
	if not Settings.reduce_motion:
		if _motion:
			_motion.kill()
		_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_motion.tween_method(_set_travel, 0.0, 1.0, travel_seconds)
		await _motion.finished
	_travel_from = Vector3.INF
	_travel = 1.0


func _set_travel(along: float) -> void:
	_travel = along
	_place_bus()


## How much of their orbit speed the planets run at: all of it on the map, less and less as
## the orbit lines fade, and none from then until it has closed that far again.
func get_orbit_share() -> float:
	return 1.0 - smoothstep(0.0, orbits_gone, _progress)


func _tween_step(from: float, to: float, seconds: float) -> void:
	if _motion:
		_motion.kill()
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_step, from, to, seconds)


# Keeps how the map is, and lets the camera out as far as the chart needs.
func _remember() -> void:
	_from = rig.position
	_from_distance = rig.distance
	_max_distance = rig.max_distance
	_bounds_center = rig.bounds_center
	_bounds_radius = rig.bounds_radius
	_sky_colors = [sky.background_color, sky.fog_color, sky.fog_accent_color, sky.star_color]
	_to = Vector3.ZERO
	var visited := star_map.get_visited()
	for system: StarSystem in visited:
		_to += system.position / visited.size()
		_systems[system] = system.visible
		for node: Node3D in system.get_contents():
			if not node.visible:
				continue
			_contents.append(node)
			# A system that didn't show has only its star on the chart.
			node.visible = system.visible
		if system.visible:
			_planets.append_array(system.get_planets())
		system.visible = true
	if capsules.visible:
		_contents.append(capsules)
	rig.max_distance = maxf(_max_distance, chart_distance)
	rig.bounds_center = _to
	rig.bounds_radius = _to.distance_to(_from) + 1.0


# Puts the map back as _remember() found it.
func _restore() -> void:
	for system: StarSystem in _systems:
		system.visible = _systems[system]
	for node: Node3D in _contents:
		node.visible = true
	_progress = 0.0
	bus.get_model().shown_at = Vector3.INF
	bus.get_model().scale = Vector3.ONE
	_systems.clear()
	_contents.clear()
	_planets.clear()
	rig.max_distance = _max_distance
	rig.bounds_center = _bounds_center
	rig.bounds_radius = _bounds_radius
	rig.move_to(_from)
	rig.set_distance(_from_distance)


# Partway through the pull back, from 0 (the map) to 1 (the chart).
func _step(progress: float) -> void:
	rig.move_to(_from.lerp(_to, progress))
	rig.set_distance(_from_distance * pow(chart_distance / _from_distance, progress))
	var orbits := 1.0 - smoothstep(0.0, orbits_gone, progress)
	# A body at no size at all has no transform to draw its parts with.
	var size := maxf(1.0 - smoothstep(planets_shrink, planets_gone, progress), 0.001)
	for planet: Planet in _planets:
		planet.orbit_opacity = orbits
		planet.body_scale = size
	heat_zone.set_opacity(size)
	_progress = progress
	_place_bus()
	var gone := progress >= planets_gone
	for node: Node3D in _contents:
		# A system that didn't show keeps only its star.
		var system := node.get_parent() as StarSystem
		node.visible = not gone and (system == null or _systems[system])
		if node is AsteroidField:
			(node as AsteroidField).set_rock_size(size)
		elif node is WarpGate or node is Stargate:
			node.scale = Vector3.ONE * size
	var plain := smoothstep(sky_fades, 1.0, progress)
	sky.background_color = _sky_colors[0].lerp(background_color, plain)
	sky.fog_color = _sky_colors[1].lerp(fog_color, plain)
	sky.fog_accent_color = _sky_colors[2].lerp(fog_accent_color, plain)
	sky.star_color = _sky_colors[3].lerp(sky_star_color, plain)


# Puts the bus's model on its way from the bus to beside its star, from when the planets
# start to shrink to the end, and as big as keeps its size on screen from where the camera
# is.
func _place_bus() -> void:
	var model := bus.get_model()
	var along := smoothstep(planets_shrink, 1.0, _progress)
	if along <= 0.0:
		model.shown_at = Vector3.INF
		model.scale = Vector3.ONE
		return
	var star := star_map.get_nearest_system(bus.global_position).global_position
	var out := bus.global_position - star
	out = Vector3(out.x, 0.0, out.z)
	var side := out.normalized() if out.length() > 0.01 else Vector3.RIGHT
	var beside := star + side * bus_star_distance
	if _travel_from.is_finite():
		beside = _travel_from.lerp(beside, _travel)
	model.shown_at = bus.global_position.lerp(beside, along)
	# The rig has just put the shot where the camera will be.
	var back := rig.global_basis.z
	var eye := rig.global_position + back * rig.distance * rig.get_view_scale()
	var depth := (eye - model.shown_at).dot(back)
	model.scale = Vector3.ONE * lerpf(1.0, bus_size * depth / bus_view_distance, along)


func _debug_toggle() -> void:
	if _in_use:
		close()
	else:
		open()
	if _debug_button:
		_debug_button.text = DEBUG_CLOSE_TEXT if _in_use else DEBUG_OPEN_TEXT
