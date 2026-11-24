class_name AsteroidField
extends Node3D
## An asteroid field: a band of rocks round the star, where [member belt] says, turning
## slowly about it as the planets do, with gaps the bus flies through freely. Flying among
## the rocks, the bus is slowed to [member rough_speed], braking into it rather than
## stopping dead, and every [member bump_seconds] a rock knocks it: everyone on board takes
## a shock of [member bump_shock] ([method Cabin.bump], which lifts a rock lover instead) and
## is thrown about in their seat, the bus rocks and the camera shakes. Holding still among
## them, or towed, costs nothing. With Shock absorbers the bus flies among them at
## [member absorbed_speed] and each shock is [member absorbed_share] as big. Put it at the
## star's centre.
##
## The rocks are two MultiMeshes, big rocks and pebbles, each one draw call, built at load
## from [RockMesh] shapes, so there is nothing to model and nothing to update per frame but
## the belt's turn. They tumble in their shader.
##
## It lowers [member FrameshiftBus.speed_cap] after the [HeatZone] has set it for the frame
## ([member Node.process_priority] 1), so the lower of the two holds, and lifts it again as
## the bus leaves the rocks, so it works with no HeatZone too.

## The bus flew into the rocks.
signal entered_rocks
## A rock knocked the bus.
signal bumped

const ALERT := preload("res://shared/icons/triangle_alert.svg")
const ROUGH_RIDE := "Rough ride!"

## Where the rocks are and where the gaps are.
@export var belt: AsteroidBelt
## The bus it slows. None, and the field only draws.
@export var bus: FrameshiftBus
## Whose passengers the bumps shock. None shocks nobody.
@export var cabin: Cabin
## Says "Rough ride!" over the bus as it flies into the rocks. None says nothing.
@export var quick_text: BusQuickText
## Turns the belt at the planets' pace, slowing when they do. None turns it at full speed.
@export var orbit_clock: OrbitClock
## Seconds per turn of the belt, at full speed. Negative turns it the other way. The gaps
## move with it, so the slower it turns the easier they are to hit: at 600 a gap halfway
## across the belt drifts about 0.18 units a second, a third of a unit while the bus crosses.
@export var orbit_period := 600.0
@export_group("Ride")
## The fastest the bus flies among the rocks, in units a second.
@export_range(0.05, 5.0, 0.05) var rough_speed := 0.4
## How fast the bus brakes to [member rough_speed] on flying in, in units a second, each
## second.
@export_range(0.1, 20.0, 0.1) var brake := 3.0
## Seconds between bumps among the rocks. The first comes on flying in.
@export_range(0.1, 10.0, 0.05) var bump_seconds := 0.8
## How much happiness each bump takes from everyone on board.
@export_range(-50.0, 0.0, 0.5) var bump_shock := -1.0
## With Shock absorbers, the fastest the bus flies among the rocks, and the share of
## [member bump_shock] each bump takes.
@export_range(0.05, 5.0, 0.05) var absorbed_speed := 0.6
@export_range(0.0, 1.0, 0.05) var absorbed_share := 0.5
## How hard the hardest bump throws the passengers about and rocks the bus, in units a
## second, each second, from one side or the other. Each bump is a third of that or more.
@export_range(0.0, 3.5, 0.1) var bump_jolt := 3.0
## How hard each bump shakes the camera, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var bump_shake := 0.15
## How far the bus may brush the rocks without hitting them: the gaps count this much wider
## and the band this much narrower, for the bus's centre.
@export_range(0.0, 1.0, 0.01) var clearance := 0.2
## How much further the bus may stray past a gap's side, among its first rocks, before they
## count: a gap flies this much wider on each side than it looks.
@export_range(0.0, 2.0, 0.01) var gap_leeway := 0.5
@export_group("Look")
@export var rock_seed := 7
@export_range(0, 10000) var rock_count := 350
@export_range(0, 20000) var pebble_count := 300
## The widest open spot left among the rocks, outside the gaps, in units: a wider one gets
## a rock of its own, so nothing but a gap looks wide enough to fly through. 0 leaves them.
@export_range(0.0, 5.0, 0.05) var open_spot := 1.3
## How far above or below the orbit plane the rocks reach, at the band's middle.
@export_range(0.0, 2.0, 0.01) var height := 0.35

# The cap it puts on the bus's speed, easing down to rough_speed among the rocks.
var _cap := INF
var _in_rocks := false
var _until_bump := 0.0


func _ready() -> void:
	process_priority = 1
	if not belt:
		belt = AsteroidBelt.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	(%Rocks as MultiMeshInstance3D).multimesh = RockScatter.scatter(
		belt, RockMesh.build(rock_seed, 1, 0.55), rock_count, 0.12, 0.75, height, rng, open_spot
	)
	(%Pebbles as MultiMeshInstance3D).multimesh = RockScatter.scatter(
		belt, RockMesh.build(rock_seed + 1, 0, 0.4), pebble_count, 0.03, 0.09, height, rng
	)


## Whether the bus is among the rocks now, flying.
func is_bus_in_rocks() -> bool:
	return _in_rocks


func _process(delta: float) -> void:
	var pace := orbit_clock.get_speed() if orbit_clock else 1.0
	if orbit_period != 0.0:
		rotation.y = wrapf(rotation.y + TAU / orbit_period * pace * delta, 0.0, TAU)
	# Each on its own, so the pebbles stop tumbling too should they get their own material.
	# The star they circle lights them, wherever the field sits on the map.
	for node: Node in [%Rocks, %Pebbles]:
		var material := (node as MultiMeshInstance3D).material_override as ShaderMaterial
		ShaderValues.show(material, &"tumble", 0.0 if Settings.reduce_motion else 1.0)
		ShaderValues.show(material, &"light_source", global_position)
	if bus:
		_ride(delta)


func _ride(delta: float) -> void:
	var flying := bus.state == FrameshiftBus.State.FLYING and not bus.is_towing()
	var was_in := _in_rocks
	var at := to_local(bus.global_position)
	_in_rocks = (
		flying
		and belt.is_in_band(at, clearance)
		and not belt.is_in_gap(at, -clearance - gap_leeway)
	)
	if not _in_rocks:
		# Leaving, it lifts the cap it put on, unless something has set another since, as
		# a HeatZone does every frame. With none, nothing else would give the speed back.
		if was_in and bus.speed_cap == _cap:
			bus.speed_cap = INF
		_cap = INF
		return
	if not was_in:
		_cap = bus.get_stats().get_stat(BusStats.Type.MAX_SPEED).get_value()
		_until_bump = 0.0
		if quick_text:
			quick_text.show_text(ROUGH_RIDE, ALERT, BusQuickText.Kind.LOSS)
		entered_rocks.emit()
	_cap = move_toward(_cap, absorbed_speed if _absorbs() else rough_speed, brake * delta)
	bus.speed_cap = minf(bus.speed_cap, _cap)
	_until_bump -= delta
	if _until_bump <= 0.0:
		_until_bump += bump_seconds
		_bump()


func _bump() -> void:
	if cabin:
		cabin.bump(bump_shock * (absorbed_share if _absorbs() else 1.0))
	# From one side or the other, a light knock or a hard one.
	var side := randf_range(0.35, 1.0) * (1.0 if randf() < 0.5 else -1.0)
	bus.felt_push.jolt(Vector2(side, randf_range(-0.5, 0.5)) * bump_jolt)
	bus.get_model().jolt(side * bump_jolt / FeltPush.MAX)
	var heading := bus.global_basis.z
	Feedback.shake(bump_shake, Vector2(heading.x, heading.z))
	bumped.emit()


# Whether the bus has Shock absorbers.
func _absorbs() -> bool:
	return bus.get_stats().get_traits().has(BusTraits.Type.SHOCK_ABSORBERS)
