class_name StarMap
extends Node
## Every star system, all in one space under [member world], in the order the player opens
## them, and how far the player has got through them. Until they are joined the bus works
## in one system at a time: only that one shows, and the camera stays over it. A promotion
## there opens the next system ([method promote]), and the bus jumps to it once it is empty
## ([method enter]). Through the stargate it goes back and forth between the systems it has
## been to, one star at a time ([method can_travel]). The promotion in the last system
## joins them: every system shows, the camera roams over all of them and zooms out
## further, and passengers travel between them. As they join, the camera pulls slowly back
## from the system the bus is in until all of them show, locked meanwhile; under Reduce
## motion it cuts there.

## The systems the bus works in, or the one it can jump to, changed.
signal changed

## Holds the [StarSystem]s, in the order they open.
@export var world: Node3D
@export var rig: CameraRig
## Takes the colours of the system the bus works in.
@export var sky: SpaceSky
## How far the camera may zoom out once the systems are joined, and where it zooms out to
## as they join.
@export_range(1.0, 400.0, 0.1, "or_greater") var joined_max_distance := 110.0
## Seconds the camera takes to pull back over every system as they join.
@export_range(0.1, 20.0, 0.1) var join_seconds := 5.0

@export_group("Joined goals")
## The goals once the systems are joined: deliver this many passengers, and keep this
## recent rating.
@export_range(1, 1000, 1) var joined_deliveries := 60
@export_range(0.0, 5.0, 0.05) var joined_rating := 4.0
## How many passengers may wait at every planet together once the systems are joined:
## [member WaitingPassengers.max_total] for the joined map, about 2 to a planet, busier
## than one system's 1.4.
@export_range(1, 200, 1) var joined_max_waiting := 30

var _systems: Array[StarSystem] = []
# The system the bus works in.
var _current := 0
# How many systems are open: the current one and those before it, and the next one once a
# promotion opens it.
var _opened := 1
# How many systems the bus has been to: the first ones, in the order they open.
var _reached := 1
var _joined := false
var _reveal: Tween


func _ready() -> void:
	if not sky:
		return
	# The sky's stars hide behind every star's halo; those of hidden systems hide nothing.
	var halos: Array[MeshInstance3D] = []
	for system: StarSystem in get_systems():
		if system.halo:
			halos.append(system.halo)
	sky.star_covers = halos


## Puts the map as a saved run had it: [param saved] from [method to_save], with the bus at
## [param bus_planet], whose system is the one it works in. Call it before the scene is
## ready, so the camera starts over that system.
func restore(saved: Dictionary, bus_planet: Planet) -> void:
	var systems := get_systems()
	_opened = clampi(SavedStarMap.get_opened(saved), 1, systems.size())
	_joined = SavedStarMap.is_joined(saved)
	_current = 0
	for i: int in systems.size():
		if bus_planet and systems[i].has_planet(bus_planet):
			_current = i
	_opened = maxi(_opened, _current + 1)
	_reached = clampi(maxi(SavedStarMap.get_reached(saved), _current + 1), 1, systems.size())
	show_systems()
	rig.position = systems[_current].position


## What a save keeps: how many systems are open and whether they are joined, and the
## system the bus works in, by name, for the main menu to show its level's loading screen.
## [method restore] finds that from the bus's planet instead.
func to_save() -> Dictionary:
	return SavedStarMap.make(_opened, _joined, String(get_current().name), _reached)


## Every star system, in the order they open.
func get_systems() -> Array[StarSystem]:
	if _systems.is_empty():
		for child: Node in world.get_children():
			if child is StarSystem:
				_systems.append(child as StarSystem)
	return _systems.duplicate()


## The system the bus works in. Once they are joined, the one it was promoted in last.
func get_current() -> StarSystem:
	return get_systems()[_current]


func is_joined() -> bool:
	return _joined


## The systems the bus has been to, in the order they open, or every one once they are
## joined.
func get_visited() -> Array[StarSystem]:
	var systems := get_systems()
	return systems if _joined else systems.slice(0, _reached)


## The last of the systems the bus has been to, whose goals the run is on, wherever the
## stargate has taken the bus since.
func get_furthest() -> StarSystem:
	return get_systems()[_reached - 1]


## Whether the bus can go through the stargate to [param system]: one it has been to, the
## one before or after the one it works in.
func can_travel(system: StarSystem) -> bool:
	var index := get_systems().find(system)
	return index >= 0 and index < _reached and absi(index - _current) == 1


## How many systems the player has been promoted out of: each opened the next, and the
## last joined them.
func count_done() -> int:
	return SavedStarMap.count_done(SavedStarMap.make(_opened, _joined, ""), get_systems().size())


## The system the bus can jump to, now that a promotion has opened it, or null.
func get_jump_target() -> StarSystem:
	if _joined or _opened <= _reached:
		return null
	return get_systems()[_reached]


## The planets passengers wait at and travel between: the current system's, or every
## system's once they are joined.
func get_active_planets() -> Array[Planet]:
	if not _joined:
		return get_current().get_planets()
	var planets: Array[Planet] = []
	for system: StarSystem in get_systems():
		planets.append_array(system.get_planets())
	return planets


## The system whose star is nearest [param point], among those that show.
func get_nearest_system(point: Vector3) -> StarSystem:
	var nearest := get_current()
	if not _joined:
		return nearest
	for system: StarSystem in get_systems():
		if system.global_position.distance_to(point) < nearest.global_position.distance_to(point):
			nearest = system
	return nearest


## A promotion: in the last system it joins them all, anywhere else it opens the next one.
func promote() -> void:
	if _joined:
		return
	if _current + 1 >= get_systems().size():
		_joined = true
		show_systems()
		_pull_back()
	else:
		_opened = maxi(_opened, _current + 2)
	changed.emit()


## The bus has jumped to [param system], or gone there through the stargate: it becomes
## the one it works in.
func enter(system: StarSystem) -> void:
	var index := get_systems().find(system)
	if index < 0:
		return
	_current = index
	_opened = maxi(_opened, index + 1)
	_reached = maxi(_reached, index + 1)
	show_systems()
	changed.emit()


# The camera eases from where it is to over every system, zooming out by the same factor
# in every equal step so the pull back reads as steady rather than rushing at the end.
func _pull_back() -> void:
	var from := rig.position
	var from_distance := rig.distance
	var to := get_bounds_center()
	if Settings.reduce_motion:
		_pull_back_step(1.0, from, from_distance, to)
		return
	rig.locked = true
	if _reveal:
		_reveal.kill()
	_reveal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal.tween_method(_pull_back_step.bind(from, from_distance, to), 0.0, 1.0, join_seconds)
	await _reveal.finished
	rig.locked = false


func _pull_back_step(progress: float, from: Vector3, from_distance: float, to: Vector3) -> void:
	rig.move_to(from.lerp(to, progress))
	rig.set_distance(from_distance * pow(joined_max_distance / from_distance, progress))


## Shows the systems the bus works in and hides the rest, keeps the camera over them and lets
## it zoom out as far as the one it works in allows, and gives the sky that one's colours.
func show_systems() -> void:
	var systems := get_systems()
	for i: int in systems.size():
		systems[i].visible = _joined or i == _current
	if _joined:
		rig.max_distance = maxf(rig.max_distance, joined_max_distance)
	else:
		rig.max_distance = get_current().max_distance
		# Further out than the new system allows, it eases back in.
		rig.zoom_to(rig.distance)
	rig.bounds_center = get_bounds_center()
	rig.bounds_radius = get_bounds_radius()
	_colour_sky(get_current())


# The sky takes [param system]'s colours. Joined, it keeps those of the last system the
# bus worked in.
func _colour_sky(system: StarSystem) -> void:
	if not sky:
		return
	sky.background_color = system.background_color
	sky.fog_color = system.fog_color
	sky.fog_accent_color = system.fog_accent_color
	sky.star_color = system.sky_star_color


## The centre of the area the camera's look-at point stays in: the current system's star,
## or the middle of every system once they are joined. In the camera rig's parent's space.
func get_bounds_center() -> Vector3:
	if not _joined:
		return get_current().position
	var center := Vector3.ZERO
	for system: StarSystem in get_systems():
		center += system.position
	return center / get_systems().size()


## How far from [method get_bounds_center] the look-at point may go: far enough to reach
## the edge of every system the bus works in.
func get_bounds_radius() -> float:
	if not _joined:
		return get_current().bounds_radius
	var center := get_bounds_center()
	var radius := 0.0
	for system: StarSystem in get_systems():
		radius = maxf(radius, center.distance_to(system.position) + system.bounds_radius)
	return radius
