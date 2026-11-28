class_name StarTravel
extends Node
## Going from one star to another through the [Stargate], from the station's Travel
## between stars ([BossPickUp]). The [StarChart] opens and stays open. The pointer on a
## star, or on its card once that is open, shows the [StarCard] above it: the star's name
## and planets, what The Boss has the player fetch there and a button to jump there, which
## works for a star one link away ([method StarMap.can_travel]). Pressed, that star's
## system becomes the one the bus works in, its lines start empty, and the bus's model
## flies there over the chart; the chart then closes into that system, where the bus
## comes out beside the planet its stargate floats by and flies in to dock. It costs no
## fuel. The Close star chart button closes the chart with nothing changed. Nothing saves
## from the jump until the chart has closed.

## How far off its planet's surface the bus comes out, on the stargate's side, and how
## fast it flies in from there, as a share of its top speed.
const ARRIVE_GAP := 2.0
const ARRIVE_SPEED := 0.6
## How far the pointer may be from a star's middle and still be on it, as a share of its
## radius on screen, and at least this many pixels.
const STAR_REACH := 1.8
const STAR_MIN_REACH := 28.0
## The gap between the top of a star's reach and its card's notch, in pixels.
const CARD_GAP := 8.0
## Seconds the Close button takes to fade in.
const FADE_SECONDS := 0.2

@export var boss_pick_up: BossPickUp
@export var star_chart: StarChart
@export var star_map: StarMap
@export var bus: FrameshiftBus
## Its lines start empty in the system the bus comes to.
@export var waiting: WaitingPassengers
## Saves nothing through a jump.
@export var saver: GameSaver
@export var card: StarCard
@export var close_button: Button

# Whether the chart is open for the player to pick a star.
var _picking := false
# The star the card is on.
var _star: StarSystem
# Where the bus comes out: the planet, and the way out from its star.
var _arrival: Planet


func _ready() -> void:
	boss_pick_up.travel_pressed.connect(open)
	card.jump_pressed.connect(_on_jump_pressed)
	close_button.pressed.connect(_close)
	close_button.hide()


func _process(_delta: float) -> void:
	if not _picking or not star_chart.is_still():
		return
	var star := _find_pointed()
	if star != _star:
		_star = star
		if star:
			card.show_star(star, _get_reach(star), boss_pick_up.get_fetch(star))
			card.appear()
		else:
			card.leave()
	if _star:
		card.place(_get_card_tip(_star))


## Opens the star chart for the player to pick a star, or lets them pick on the open one.
func open() -> void:
	if _picking:
		return
	_picking = true
	if not star_chart.is_open():
		await star_chart.open()
	close_button.modulate.a = 0.0
	close_button.show()
	create_tween().tween_property(close_button, ^"modulate:a", 1.0, FADE_SECONDS)


func _close() -> void:
	if not _picking or not star_chart.is_still():
		return
	_picking = false
	_drop_card()
	await star_chart.close()


func _drop_card() -> void:
	_star = null
	card.leave()
	close_button.hide()


func _on_jump_pressed() -> void:
	var star := _star
	if not _picking or not star or not star_map.can_travel(star) or not star_chart.is_still():
		return
	_picking = false
	_drop_card()
	saver.holding = true
	await star_chart.travel(_enter.bind(star))
	bus.process_mode = Node.PROCESS_MODE_INHERIT
	# The way in from the stargate costs no fuel either.
	var tank := bus.get_fuel_tank()
	bus.docked.connect(_refill.bind(tank.fuel), CONNECT_ONE_SHOT)
	bus.fly_in(RouteStop.at_planet(_arrival), bus.max_speed * ARRIVE_SPEED)
	await star_chart.close()
	saver.holding = false


func _refill(_planet: Planet, fuel: float) -> void:
	bus.get_fuel_tank().fuel = fuel


# The star map goes over to [param system], and the bus waits, held still, where it comes
# out: beside the planet its stargate floats by, facing the way it came.
func _enter(system: StarSystem) -> void:
	var from := star_map.get_current().global_position
	star_map.enter(system)
	waiting.set_planets(system.get_planets())
	var gate := Stargate.find(get_tree(), system)
	_arrival = gate.planet if gate else system.home
	var out := RouteStop.flat(_arrival.get_body_global_position() - system.global_position)
	out = out.normalized() if out.length_squared() > 1e-6 else Vector3.RIGHT
	bus.process_mode = Node.PROCESS_MODE_DISABLED
	bus.global_position = RouteStop.approach_point(_arrival, out, ARRIVE_GAP)
	var heading := RouteStop.flat(system.global_position - from)
	bus.rotation.y = atan2(heading.x, heading.z)


func _get_reach(system: StarSystem) -> StarCard.Reach:
	if system == star_map.get_current():
		return StarCard.Reach.HERE
	return StarCard.Reach.NEAR if star_map.can_travel(system) else StarCard.Reach.FAR


# The star the pointer is on, or the one whose card it is on or on its way to.
func _find_pointed() -> StarSystem:
	var pointer := get_viewport().get_mouse_position()
	for system: StarSystem in star_map.get_visited():
		if pointer.distance_to(_on_screen(system.global_position)) <= _get_reach_pixels(system):
			return system
	if _star and card.is_shown():
		# From the card's top down to the star's middle, so nothing drops it on the way
		# from the star to the button.
		var down := _on_screen(_star.global_position).y - card.position.y
		if Rect2(card.position, Vector2(card.size.x, down)).has_point(pointer):
			return _star
	return null


func _get_card_tip(system: StarSystem) -> Vector2:
	var middle := _on_screen(system.global_position)
	return middle - Vector2(0.0, _get_reach_pixels(system) + CARD_GAP)


func _get_reach_pixels(system: StarSystem) -> float:
	var camera := get_viewport().get_camera_3d()
	var edge := system.global_position + camera.global_basis.x * system.star_radius
	var radius := _on_screen(system.global_position).distance_to(_on_screen(edge))
	return maxf(radius * STAR_REACH, STAR_MIN_REACH)


func _on_screen(point: Vector3) -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(point)
