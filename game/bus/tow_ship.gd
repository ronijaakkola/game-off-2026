class_name TowShip
extends Node3D
## A tow ship (`models/tow_ship.glb`: a stubby red tug with a tow boom over its stern) that
## comes for a bus that ran out of fuel and pulls it to a planet. [method come_for]
## frameshifts it in just off the planet's surface and sends it to a point ahead of the bus,
## toward the planet. There it swings its stern round to the bus and shoots a cable from its
## boom to the bus's nose; once the cable latches on, it emits [signal hitched]. It then
## pulls ahead until the cable is taut and keeps ahead of the bus, facing away from it,
## while the bus flies there at tow speed. The cable hangs in a bow while it is slack,
## twangs as it goes taut and swings behind the ship's turns; under Reduce motion it only
## bows. The ship never goes closer to the planet than where it shifted in, so near the
## planet it moves round to the bus's side. Once the bus starts to park, it lets go and
## reels the cable in, veers off away from the bus and the planet and frameshifts out, then
## frees itself. A frameshift stretches the model long and thin along its heading as it
## jumps, and leaves a streak along the jump that fades. A beacon on its roof blinks while
## it works, and it leans into its turns. It moves on the orbit plane, in global space, and
## faces its +Z, like the bus.

## It reached the bus and hitched on, so the bus can set off.
signal hitched

enum Phase { IDLE, SHIFTING_IN, APPROACHING, HITCHING, TOWING, LEAVING, SHIFTING_OUT, GONE }

# From the ship's centre to the bus's while hitched.
const HITCH_DISTANCE := 1.4
# How close to its hitch point the ship gets to hitch on.
const HITCH_REACH := 0.05
# How much closer to the bus the ship hitches on, so the cable starts slack, and how fast
# the ship then pulls ahead to take the slack up.
const SLACK := 0.22
const PULL_SPEED := 0.45
# The furthest a slack cable bows.
const BOW_MAX := 0.2
# Where the cable ties on: the tip of the ship's boom and the bus's nose, from their
# centres.
const SHIP_HOOK := Vector3(0.0, 0.1, -0.33)
const BUS_HOOK := Vector3(0.0, -0.08, 0.45)
# Hitching, how much faster the ship turns its stern to the bus than it turns in flight,
# and how far off, in radians, it may still be when it shoots the cable.
const HITCH_TURN := 1.5
const HITCH_AIM := 0.9
# Seconds the cable takes to reach the bus, and to reel back in.
const CABLE_SECONDS := 0.3
const REEL_SECONDS := 0.35
# The cable's thickness, and how many straight pieces draw its bow.
const CABLE_RADIUS := 0.012
const CABLE_PIECES := 10
# The cable's swing: how hard its middle springs back to where it hangs, how fast that
# dies down, how far it may swing, and how fast the twang throws it as it goes taut.
const SWING_SPRING := 160.0
const SWING_DAMPING := 9.0
const SWING_MAX := 0.25
const TWANG_SPEED := 1.6
# How far the model leans into a turn, in radians per radian a second.
const BANK := 0.12
# From the planet's surface to the ship's centre where it appears, and where it lets go.
const PLANET_GAP := 0.6
# How fast the hitched ship follows its point ahead of the bus: the share of the way left
# it covers per second.
const FOLLOW_SMOOTHING := 6.0
# Seconds a frameshift jump takes, how far it goes, and how long and how thin the model
# stretches at the jump's far end, as shares of its size.
const SHIFT_SECONDS := 0.3
const SHIFT_DISTANCE := 2.5
const SHIFT_STRETCH := 6.0
const SHIFT_THIN := 0.12
# Seconds the streak a jump leaves takes to fade, and how see-through it starts.
const STREAK_FADE_SECONDS := 0.5
const STREAK_OPACITY := 0.85
# Seconds for the beacon to blink on and off once.
const BEACON_PERIOD := 0.8
# How fast the thrusters' glow changes, per second.
const THRUST_FADE := 2.0

## Top speed on its way to the bus and away.
@export_range(0.1, 20.0, 0.05) var max_speed := 1.8
## Speed gained or lost per second.
@export_range(0.1, 20.0, 0.05) var acceleration := 1.6
## Radians per second.
@export_range(0.1, 20.0, 0.1) var turn_speed := 3.0
## Seconds it flies off after letting go before it frameshifts out.
@export_range(0.0, 10.0, 0.1) var leave_seconds := 0.8

var phase := Phase.IDLE

var _bus: FrameshiftBus
var _planet: Planet
var _speed := 0.0
var _time := 0.0
var _leave_time := 0.0
var _leave_direction := Vector3.FORWARD
# The jump under way: seconds into it, and where it starts and ends.
var _shift_time := 0.0
var _shift_from := Vector3.ZERO
var _shift_to := Vector3.ZERO
# How much of the streak shows, from 1 as a jump ends to 0 once it has faded.
var _streak := 0.0
var _streak_material: StandardMaterial3D
# How far the cable reaches from the ship's hook to the bus's, 0 to 1, and whether the
# ship is paying it out or holding the bus with it, rather than reeling it in.
var _cable_out := 0.0
var _latched := false
var _cable_mesh := ImmediateMesh.new()
# The middle of the cable's swing away from where it hangs, and how fast, in global space.
var _swing := Vector3.ZERO
var _swing_velocity := Vector3.ZERO
var _cable_middle := Vector3.ZERO
# How far ahead of the bus the ship keeps: SLACK short of HITCH_DISTANCE until it has
# pulled the cable taut.
var _lead := HITCH_DISTANCE - SLACK
var _heading := 0.0


func _ready() -> void:
	(%Model as Node3D).hide()
	(%Beacon as Node3D).hide()
	(%Cable as MeshInstance3D).mesh = _cable_mesh
	(%Cable as Node3D).hide()
	(%Hook as Node3D).hide()
	(%Streak as Node3D).hide()
	# Its own copy, so fading it fades no other ship's.
	var streak := %Streak as MeshInstance3D
	_streak_material = (streak.material_override as StandardMaterial3D).duplicate()
	streak.material_override = _streak_material


## Sends the ship from just off [param planet] to [param bus], to tow it there. It
## frameshifts in along the planet's edge, to the point just off it facing the bus, so the
## jump never crosses the planet.
func come_for(bus: FrameshiftBus, planet: Planet) -> void:
	_bus = bus
	_planet = planet
	var center := _planet_center()
	var out := _flat(bus.global_position) - center
	var direction := out.normalized() if out.length_squared() > 1e-6 else Vector3.BACK
	var along_edge := Vector3.UP.cross(direction)
	rotation.y = atan2(along_edge.x, along_edge.z)
	_heading = rotation.y
	_shift_to = center + direction * (planet.get_body_radius() + PLANET_GAP)
	_shift_from = _shift_to - along_edge * SHIFT_DISTANCE
	_start_shift(Phase.SHIFTING_IN)


func _process(delta: float) -> void:
	_time += delta
	_streak = move_toward(_streak, 0.0, delta / STREAK_FADE_SECONDS)
	match phase:
		Phase.SHIFTING_IN, Phase.SHIFTING_OUT:
			_shift(delta)
		Phase.APPROACHING:
			_approach(delta)
		Phase.HITCHING:
			_hitch(delta)
		Phase.TOWING:
			_tow(delta)
		Phase.LEAVING:
			_leave(delta)
		Phase.GONE:
			if _streak <= 0.0:
				queue_free()
	var model := %Model as BusModel
	var working := phase != Phase.IDLE and phase != Phase.GONE
	model.thrust = move_toward(model.thrust, 1.0 if working else 0.0, delta * THRUST_FADE)
	var blink := fmod(_time, BEACON_PERIOD) < BEACON_PERIOD * 0.5
	var steady := phase in [Phase.APPROACHING, Phase.HITCHING, Phase.TOWING, Phase.LEAVING]
	(%Beacon as Node3D).visible = steady and blink
	_lean(delta)
	if not _latched:
		_cable_out = move_toward(_cable_out, 0.0, delta / REEL_SECONDS)
	_draw_cable(delta)
	_draw_streak()


func _approach(delta: float) -> void:
	if not _has_bus():
		_let_go()
		return
	var to_hitch := _flat(_hitch_point() - global_position)
	var distance := to_hitch.length()
	if distance < HITCH_REACH:
		phase = Phase.HITCHING
		return
	_turn_toward(to_hitch, delta)
	# Slow to a crawl while facing away, so it turns rather than circling the point.
	var facing := maxf(_forward().dot(to_hitch / distance), 0.0)
	var limit := minf(max_speed, sqrt(2.0 * acceleration * distance))
	_speed = move_toward(_speed, limit * facing * facing, acceleration * delta)
	global_position += _forward() * minf(_speed * delta, distance)


# Holds close ahead of the bus and swings its stern round to it, then shoots the cable
# across. The bus is hitched once the cable reaches it.
func _hitch(delta: float) -> void:
	if not _has_bus():
		_let_go()
		return
	_keep_ahead(delta)
	var away := _flat(global_position - _bus.global_position)
	_turn_toward(away, delta * HITCH_TURN)
	var off := absf(angle_difference(rotation.y, atan2(away.x, away.z)))
	if _cable_out <= 0.0 and off > HITCH_AIM:
		return
	_latched = true
	_cable_out = move_toward(_cable_out, 1.0, delta / CABLE_SECONDS)
	if _cable_out >= 1.0:
		phase = Phase.TOWING
		hitched.emit()


# Pulls ahead until the cable is taut and keeps there, facing away from the bus, until the
# bus starts to park.
func _tow(delta: float) -> void:
	if not _has_bus() or not _bus.is_towing() or _bus.state == FrameshiftBus.State.PARKING:
		_let_go()
		return
	if _lead < HITCH_DISTANCE:
		_lead = move_toward(_lead, HITCH_DISTANCE, PULL_SPEED * delta)
		if _lead >= HITCH_DISTANCE and not Settings.reduce_motion:
			var side := _forward().cross(Vector3.UP)
			_swing_velocity += side * TWANG_SPEED
	_keep_ahead(delta)
	_turn_toward(_flat(global_position - _bus.global_position), delta)


func _keep_ahead(delta: float) -> void:
	var weight := 1.0 - exp(-FOLLOW_SMOOTHING * delta)
	global_position = global_position.lerp(_hitch_point(), weight)


# Veers off away from the bus and the planet, then frameshifts out along its heading.
func _leave(delta: float) -> void:
	_leave_time += delta
	_turn_toward(_leave_direction, delta)
	var facing := maxf(_forward().dot(_leave_direction), 0.0)
	_speed = move_toward(_speed, max_speed * facing * facing, acceleration * delta)
	global_position += _forward() * _speed * delta
	if _leave_time >= leave_seconds:
		_shift_from = global_position
		_shift_to = global_position + _forward() * SHIFT_DISTANCE
		_start_shift(Phase.SHIFTING_OUT)


func _start_shift(shift_phase: Phase) -> void:
	phase = shift_phase
	_shift_time = 0.0
	global_position = _shift_from
	(%Model as Node3D).show()
	_stretch(1.0 if shift_phase == Phase.SHIFTING_IN else 0.0)


# A frameshift jump from _shift_from to _shift_to. Shifting in, it slows into place and
# shrinks back from long and thin; shifting out, it speeds away and stretches out, then
# vanishes. The streak runs along the jump.
func _shift(delta: float) -> void:
	_shift_time += delta
	var done := clampf(_shift_time / SHIFT_SECONDS, 0.0, 1.0)
	var shifting_in := phase == Phase.SHIFTING_IN
	# How far along the jump, eased toward its slow end.
	var along := 1.0 - (1.0 - done) * (1.0 - done) if shifting_in else done * done
	global_position = _shift_from.lerp(_shift_to, along)
	_stretch(1.0 - done if shifting_in else done)
	_streak = 1.0
	if done < 1.0:
		return
	if shifting_in:
		_speed = max_speed * 0.5
		phase = Phase.APPROACHING
	else:
		(%Model as Node3D).hide()
		phase = Phase.GONE


# Stretches the model along its heading and thins it, by [param amount] from 0 (its own
# shape) to 1 (the far end of a jump).
func _stretch(amount: float) -> void:
	var thin := lerpf(1.0, SHIFT_THIN, amount)
	(%Model as Node3D).scale = Vector3(thin, thin, lerpf(1.0, SHIFT_STRETCH, amount))


func _let_go() -> void:
	phase = Phase.LEAVING
	_latched = false
	_leave_time = 0.0
	_speed = 0.0
	_leave_direction = _forward()
	if _has_bus():
		var from_bus := _flat(global_position - _bus.global_position).normalized()
		var from_planet := (_flat(global_position) - _planet_center()).normalized()
		var away := from_bus + from_planet
		if away.length_squared() > 1e-6:
			_leave_direction = away.normalized()


# A flat streak on the orbit plane along the last jump, from its start to where the ship
# is, fading out once the jump is over.
func _draw_streak() -> void:
	var streak := %Streak as MeshInstance3D
	var end := _shift_to if phase == Phase.GONE else global_position
	var span := _flat(end - _shift_from)
	var length := span.length()
	streak.visible = _streak > 0.0 and length > 1e-3
	if not streak.visible:
		return
	_streak_material.albedo_color.a = _streak * STREAK_OPACITY
	var along := span / length
	# The streak mesh is a plane one unit long along its z.
	var streak_basis := Basis(Vector3.UP.cross(along), Vector3.UP, along * length)
	streak.global_transform = Transform3D(streak_basis, _flat(_shift_from + end) * 0.5)


# The cable from the ship's boom toward the bus's nose, as far as it has reached, with the
# hook at its end. Until the ship has pulled ahead to HITCH_DISTANCE it hangs in a bow,
# down and to one side, and its middle swings on a spring behind the ship's and the bus's
# moves.
func _draw_cable(delta: float) -> void:
	var cable := %Cable as MeshInstance3D
	var hook := %Hook as Node3D
	cable.visible = _cable_out > 0.0 and _has_bus()
	hook.visible = cable.visible
	_cable_mesh.clear_surfaces()
	if not cable.visible:
		_swing = Vector3.ZERO
		_swing_velocity = Vector3.ZERO
		return
	var from := global_transform * SHIP_HOOK
	var reach := 1.0 - (1.0 - _cable_out) * (1.0 - _cable_out)
	var to := from.lerp(_bus.global_transform * BUS_HOOK, reach)
	var span := to - from
	var length := span.length()
	if length < 1e-4:
		cable.hide()
		hook.hide()
		return
	var along := span / length
	var side := along.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
	# A parabola longer than its span by the slack bows about this far.
	var slack := (HITCH_DISTANCE - _lead) * reach
	var bow := minf(sqrt(0.375 * length * slack), BOW_MAX)
	var middle := (from + to) * 0.5
	_swing_cable(middle, delta)
	var hang := (side + Vector3.DOWN * 0.5).normalized() * bow + _swing
	# A curve from hook to hook through the bowed middle.
	var control := middle + hang * 2.0
	var points := PackedVector3Array()
	for i: int in CABLE_PIECES + 1:
		var t := float(i) / CABLE_PIECES
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	_draw_tube(points)
	var end := (to - points[-2]).normalized()
	var hook_side := end.cross(Vector3.UP).normalized()
	hook.global_transform = Transform3D(Basis(hook_side, end.cross(hook_side), end), to)


# Moves the cable's swing on by [param delta]: its middle stays behind as the cable's ends
# move, and springs back. Still under Reduce motion.
func _swing_cable(middle: Vector3, delta: float) -> void:
	var moved := middle - _cable_middle
	_cable_middle = middle
	if Settings.reduce_motion or delta <= 0.0:
		_swing = Vector3.ZERO
		return
	# A jump, such as the first frame it shows, is no swing.
	if moved.length() < SWING_MAX:
		_swing -= moved
	_swing_velocity += (-SWING_SPRING * _swing - SWING_DAMPING * _swing_velocity) * delta
	_swing = (_swing + _swing_velocity * delta).limit_length(SWING_MAX)


# A four-sided tube through [param points], in global space.
func _draw_tube(points: PackedVector3Array) -> void:
	_cable_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i: int in points.size():
		var along := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var side := along.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 1e-8 else Vector3.RIGHT
		var up := side.cross(along).normalized()
		(
			rings
			. append(
				PackedVector3Array(
					[
						points[i] + side * CABLE_RADIUS,
						points[i] + up * CABLE_RADIUS,
						points[i] - side * CABLE_RADIUS,
						points[i] - up * CABLE_RADIUS,
					]
				)
			)
		)
	for i: int in rings.size() - 1:
		for corner: int in 4:
			var next := (corner + 1) % 4
			_cable_mesh.surface_add_vertex(rings[i][corner])
			_cable_mesh.surface_add_vertex(rings[i + 1][corner])
			_cable_mesh.surface_add_vertex(rings[i + 1][next])
			_cable_mesh.surface_add_vertex(rings[i][corner])
			_cable_mesh.surface_add_vertex(rings[i + 1][next])
			_cable_mesh.surface_add_vertex(rings[i][next])
	_cable_mesh.surface_end()


# Leans the model into the ship's turn.
func _lean(delta: float) -> void:
	var model := %Model as Node3D
	var turn_rate := angle_difference(_heading, rotation.y) / delta if delta > 0.0 else 0.0
	_heading = rotation.y
	var lean := clampf(-turn_rate * BANK, -0.5, 0.5)
	model.rotation.z = lerp_angle(model.rotation.z, lean, 1.0 - exp(-8.0 * delta))


# _lead ahead of the bus, toward the planet, but no closer to the planet than
# PLANET_GAP off its surface: when the bus is near, the point beside the bus on that
# circle, on the side the ship is already on.
func _hitch_point() -> Vector3:
	var bus := _flat(_bus.global_position)
	var direction := _tow_direction()
	var ahead := bus + direction * _lead
	var center := _planet_center()
	var keep := _planet.get_body_radius() + PLANET_GAP
	if ahead.distance_to(center) >= keep:
		return ahead
	# Where the circle round the bus meets the circle the ship keeps to.
	var apart := bus.distance_to(center)
	if apart >= keep + _lead or apart <= absf(keep - _lead):
		return center - direction * keep
	var along := (_lead * _lead - keep * keep + apart * apart) / (2.0 * apart)
	var across := sqrt(maxf(_lead * _lead - along * along, 0.0))
	var side := direction.cross(Vector3.UP)
	var middle := bus + direction * along
	if (_flat(global_position) - middle).dot(side) < 0.0:
		side = -side
	return middle + side * across


func _tow_direction() -> Vector3:
	var to_planet := _planet_center() - _flat(_bus.global_position)
	if to_planet.length_squared() < 1e-6:
		return _forward()
	return to_planet.normalized()


func _has_bus() -> bool:
	return is_instance_valid(_bus) and is_instance_valid(_planet)


func _planet_center() -> Vector3:
	return _flat(_planet.get_body_global_position())


func _turn_toward(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 1e-6:
		return
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), turn_speed * delta)


func _forward() -> Vector3:
	return _flat(global_basis.z).normalized()


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
