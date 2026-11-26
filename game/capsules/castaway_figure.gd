class_name CastawayFigure
extends Node3D
## The [Castaway] out of their capsule, waiting to hear whether the bus takes them: the
## small figure a kicked passenger is, in their colour. It pops out of the capsule and up,
## fast at first, tumbling, then trails after the bus, floating over it. Taken on board
## ([method board]), it drops into the bus, shrinking; turned down ([method leave]), it
## drifts off and shrinks away. It screams as it comes out and as it is left, in its race's
## voice, as a kicked passenger does. When they hop out of the bus ([method hop_out]), it
## comes out of the door and floats off in space for a while. Under Reduce motion it doesn't
## tumble.

## Out and waiting, dropping into the bus, drifting off, or floating off after a hop.
enum State { OUT, BOARDING, LEAVING, HOPPING }

const FIGURE := preload("res://game/passengers/passenger_figure.tscn")
## How many times a kicked passenger's size it is, so it reads from the camera.
const SIZE := 1.8
## How far over the capsule and the bus it floats, and the seconds it takes to pop out.
const RISE := 0.45
const POP_SECONDS := 0.35
## How fast it closes on the bus once out: the share of the way left it covers a second.
const FOLLOW := 3.0
## Seconds it takes to drop into the bus, and to drift off and shrink away.
const BOARD_SECONDS := 0.45
const LEAVE_SECONDS := 2.0
## Units a second it drifts off at, away from the bus and up.
const LEAVE_SPEED := 0.7
## Seconds it floats in space after hopping out of the bus, shrinking away toward the end,
## and the units a second it floats at.
const HOP_SECONDS := 8.0
const HOP_SPEED := 0.3
## Radians a second it tumbles.
const SPIN_SPEED := 2.5
const SPIN_AXIS := Vector3(0.4, 1.0, 0.3)

var _state := State.OUT
var _age := 0.0
# Seconds since it was taken on board or left.
var _ending := 0.0
var _from := Vector3.ZERO
var _velocity := Vector3.ZERO
var _bus: Node3D
var _speaker: VoiceSpeaker


func _process(delta: float) -> void:
	_age += delta
	if not Settings.reduce_motion:
		rotate(SPIN_AXIS.normalized(), SPIN_SPEED * delta)
	var size := SIZE * ease(clampf(_age / POP_SECONDS, 0.0, 1.0), 0.3)
	if _state == State.OUT:
		if _age < POP_SECONDS or not _bus:
			global_position = _from + Vector3.UP * RISE * (size / SIZE)
		else:
			var over := _bus.global_position + Vector3.UP * RISE
			global_position = global_position.lerp(over, 1.0 - exp(-FOLLOW * delta))
		scale = Vector3.ONE * maxf(size, 0.001)
		return
	_ending += delta
	var seconds := BOARD_SECONDS if _state == State.BOARDING else LEAVE_SECONDS
	if _state == State.HOPPING:
		seconds = HOP_SECONDS
	if _ending >= seconds:
		queue_free()
		return
	var gone := _ending / seconds
	if _state == State.BOARDING:
		global_position = _from.lerp(_bus.global_position, smoothstep(0.0, 1.0, gone))
		scale = Vector3.ONE * maxf(size * (1.0 - 0.9 * gone), 0.001)
	else:
		global_position += _velocity * delta
		scale = Vector3.ONE * maxf(size * (1.0 - ease(gone, 3.0)), 0.001)


## Comes out of a capsule at [param from] (global space) as [param passenger], in their
## skin colour and voice, lit from [param light_source], and trails after [param bus].
func emerge(from: Vector3, passenger: Passenger, light_source: Vector3, bus: Node3D) -> void:
	_bus = bus
	_appear(from, passenger, light_source)


## Hops out of the bus's door at [param from] (global space), along [param out], as
## [param passenger], lit from [param light_source]: it floats off in space, screaming, and
## shrinks away after [constant HOP_SECONDS].
func hop_out(from: Vector3, out: Vector3, passenger: Passenger, light_source: Vector3) -> void:
	_state = State.HOPPING
	_velocity = (out + Vector3.UP * 0.5) * HOP_SPEED
	_appear(from, passenger, light_source)


func _appear(from: Vector3, passenger: Passenger, light_source: Vector3) -> void:
	_from = from
	global_position = from
	scale = Vector3.ONE * 0.001
	var figure := FIGURE.instantiate() as PassengerFigure
	figure.paint(passenger.look.skin_color, light_source)
	add_child(figure)
	_speaker = VoiceSpeaker.new()
	add_child(_speaker)
	_speaker.begin(passenger.race, passenger.name)
	_speaker.play_kicked()


## The bus takes them: it drops into the bus and is gone.
func board() -> void:
	_state = State.BOARDING
	_from = global_position


## The bus doesn't take them: it drifts off, screaming, and shrinks away.
func leave() -> void:
	_state = State.LEAVING
	var away := global_position - _bus.global_position if _bus else Vector3.ZERO
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	_velocity = (away + Vector3.UP * 0.5) * LEAVE_SPEED
	_speaker.play_kicked()
