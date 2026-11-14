class_name SystemJump
extends Node
## The bus's jump from one star system to the next, which [method start] begins with the
## bus docked. The bus turns to face the next system's home planet, its drive shaking and
## its thrusters lit, then frameshifts out as the tow ship does ([FrameshiftShift]). The
## camera, locked, eases across to the next system meanwhile, and the bus frameshifts in a
## little way off its home planet, then flies in and docks there. The bus does nothing of
## its own through it. Under Reduce motion the camera and the bus cut straight there.

## The camera is over [param system] and the bus is about to shift in there.
signal crossed(system: StarSystem)
## The bus has come out of the jump at [param system] and is flying in to its home planet.
signal finished(system: StarSystem)

enum Phase { NONE, TURNING, SHIFTING_OUT, CROSSING, SHIFTING_IN }

## Seconds the bus turns and its drive builds up before it shifts out.
const TURN_SECONDS := 1.0
## Radians a second the bus turns at meanwhile.
const TURN_SPEED := 2.5
## Seconds the camera takes to cross to the next system.
const CROSS_SECONDS := 2.6
## How far off its home planet's surface the bus comes out of the jump, and how fast it
## flies in from there, as a share of its top speed.
const ARRIVE_GAP := 2.0
const ARRIVE_SPEED := 0.6
## How far the camera's look-at point may go while it crosses: anywhere.
const CROSS_BOUNDS := 10000.0

@export var bus: FrameshiftBus
@export var rig: CameraRig

var _phase := Phase.NONE
var _target: StarSystem
var _direction := Vector3.BACK
var _time := 0.0
var _motion: Tween


func _ready() -> void:
	(%Shift as FrameshiftShift).finished.connect(_on_shift_finished)


func _process(delta: float) -> void:
	(%Shift as FrameshiftShift).advance(delta)
	if _phase != Phase.TURNING:
		return
	_time += delta
	var heading := atan2(_direction.x, _direction.z)
	bus.rotation.y = rotate_toward(bus.rotation.y, heading, TURN_SPEED * delta)
	var charge := clampf(_time / TURN_SECONDS, 0.0, 1.0)
	bus.get_model().animate(delta, true, charge, 0.0, 1.0)
	if _time >= TURN_SECONDS:
		_shift_out()


## Whether a jump is under way.
func is_jumping() -> bool:
	return _phase != Phase.NONE


## Jumps the docked bus to [param target], to dock at its home planet.
func start(target: StarSystem) -> void:
	if is_jumping() or not target.home:
		return
	_target = target
	_direction = _flat(target.home.get_body_global_position() - bus.global_position)
	_direction = _direction.normalized() if _direction.length_squared() > 1e-6 else Vector3.BACK
	bus.process_mode = Node.PROCESS_MODE_DISABLED
	rig.locked = true
	rig.bounds_radius = CROSS_BOUNDS
	target.visible = true
	if Settings.reduce_motion:
		rig.move_to(target.position)
		crossed.emit(target)
		bus.rotation.y = atan2(_direction.x, _direction.z)
		bus.global_position = _arrival_point()
		_arrive()
		return
	_time = 0.0
	_phase = Phase.TURNING


func _shift_out() -> void:
	_phase = Phase.SHIFTING_OUT
	var from := bus.global_position
	var to := from + _direction * FrameshiftShift.DISTANCE
	(%Shift as FrameshiftShift).shift_out(bus, bus.get_model(), from, to)
	if _motion:
		_motion.kill()
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_cross.bind(rig.position, _target.position), 0.0, 1.0, CROSS_SECONDS)
	_motion.finished.connect(_shift_in)


func _cross(progress: float, from: Vector3, to: Vector3) -> void:
	rig.move_to(from.lerp(to, progress))


func _shift_in() -> void:
	crossed.emit(_target)
	_phase = Phase.SHIFTING_IN
	bus.rotation.y = atan2(_direction.x, _direction.z)
	var to := _arrival_point()
	var from := to - _direction * FrameshiftShift.DISTANCE
	(%Shift as FrameshiftShift).shift_in(bus, bus.get_model(), from, to)


func _on_shift_finished() -> void:
	if _phase == Phase.SHIFTING_IN:
		_arrive()


func _arrive() -> void:
	_phase = Phase.NONE
	bus.get_model().show()
	bus.process_mode = Node.PROCESS_MODE_INHERIT
	bus.fly_in(_target.home, bus.max_speed * ARRIVE_SPEED)
	rig.locked = false
	finished.emit(_target)


# Where the bus comes out of the jump: off the home planet's side it came from.
func _arrival_point() -> Vector3:
	return RouteStop.approach_point(_target.home, -_direction, ARRIVE_GAP)


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
