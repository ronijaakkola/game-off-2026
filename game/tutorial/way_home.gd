class_name WayHome
extends RefCounted
## The [Tutorial]'s way home from the destination, by way of a point in space: the player
## sets a waypoint on a marked spot above home, toward the destination
## ([method get_spot]), and flies there, then, holding in space, sets the course home and
## flies on. Each course has a card
## ([method get_card]) with a ring: the spot, then home. Only those can be the course, a
## click near the spot sets it in the spot's middle, and once set the course locks, so the
## one thing left is to frameshift. Leaving the first time, the whole way is set to burn
## [constant FUEL] of the tank.

enum Part { SPOT, LEAVE, FLY_SPOT, HOME, FLY_HOME }

## The share of the tank the way home burns.
const FUEL := 0.75
## Where the spot is from home's centre, on the orbit plane: this far toward the
## destination, and this far up the screen.
const SPOT_ALONG := 6.0
const SPOT_UP := 5.0
## How far from the spot a right click still sets the waypoint, in units.
const SPOT_REACH := 1.5
## The size of the spot's ring, as the radius of a ball, in units.
const SPOT_RADIUS := 0.5

var _tutorial: Tutorial
var _rules: TutorialRules
var _part := Part.SPOT
# Up the screen, on the orbit plane: the way the camera faces.
var _up: Vector3


func _init(tutorial: Tutorial, rules: TutorialRules) -> void:
	_tutorial = tutorial
	_rules = rules
	var facing := -tutorial.get_viewport().get_camera_3d().global_basis.z
	_up = RouteStop.flat(facing).normalized()


## The marked spot, on the orbit plane.
func get_spot() -> Vector3:
	var home := RouteStop.flat(_tutorial.home.get_body_global_position())
	var away := RouteStop.flat(_tutorial.destination.get_body_global_position()) - home
	return home + away.normalized() * SPOT_ALONG + _up * SPOT_UP


## The stop to add for the player's click on [param stop], or null when they may not: a
## point near the spot, as the spot itself, then home.
func fit(stop: RouteStop) -> RouteStop:
	match _part:
		Part.SPOT:
			var near := RouteStop.flat(stop.point).distance_to(get_spot()) <= SPOT_REACH
			return RouteStop.at_point(get_spot()) if not stop.planet and near else null
		Part.HOME:
			return stop if stop.planet == _tutorial.home else null
	return null


## Every frame of the way home: moves on through its parts, locks a course once it is set,
## and keeps the card on what it asks for.
func update() -> void:
	var t := _tutorial
	var bus := t.bus
	var flying := bus.state == FrameshiftBus.State.FLYING
	match _part:
		Part.SPOT:
			if not bus.get_route_stops().is_empty():
				_part = Part.LEAVE
		Part.LEAVE:
			if flying:
				_set_burn()
				_part = Part.FLY_SPOT
		Part.FLY_SPOT:
			if bus.state == FrameshiftBus.State.HOLDING:
				_part = Part.HOME
		Part.HOME:
			if flying:
				_part = Part.FLY_HOME
	# Set, a course is kept: the one thing left is to frameshift.
	bus.route_locked = not bus.get_route_stops().is_empty()
	var camera := t.get_viewport().get_camera_3d()
	var at_home := _part in [Part.HOME, Part.FLY_HOME]
	var home := t.home
	t.guide.target_rect = (
		ScreenPick.square_around(camera, home.get_body_global_position(), home.get_body_radius())
		if at_home
		else ScreenPick.square_around(camera, get_spot(), SPOT_RADIUS)
	)


## The card the part asks for, by its name in [constant TutorialCards.CARDS], or empty for
## none.
func get_card() -> String:
	match _part:
		Part.SPOT:
			return "SPOT"
		Part.HOME:
			return "HOME"
	return ""


## Whether the bus has flown home and docked there.
func is_home() -> bool:
	var bus := _tutorial.bus
	var docked := bus.is_at_planet() and bus.get_docked_planet() == _tutorial.home
	return _part == Part.FLY_HOME and docked


# The way from where the bus leaves through the spot to home burns FUEL of the tank.
func _set_burn() -> void:
	var bus := _tutorial.bus
	var from := RouteStop.flat(bus.global_position)
	var spot := get_spot()
	var dock := RouteStop.at_planet(_tutorial.home).get_target(spot, bus.dock_gap)
	_rules.set_burn(FUEL, from.distance_to(spot) + spot.distance_to(dock))
