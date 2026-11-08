class_name KickedPassenger
extends Node3D
## A passenger kicked off the bus: a small, soft human figure in a star jump, arms and
## legs spread, all in their skin colour, thrown out of the bus's door. It flies off,
## slowing as it goes and tumbling, then shrinks away and frees itself. Under Reduce motion
## it is still thrown, but doesn't tumble. It screams as it goes, quietly, and the scream
## fades out fast, as if it flew away from the bus.

const SHADER := preload("res://shared/two_tone.gdshader")
const SCREAM := preload("res://game/passengers/wilhelm_scream.ogg")

## How fast it leaves the door, out of it and upward, in units per second.
@export_range(0.0, 5.0, 0.05) var throw_speed := 0.5
@export_range(0.0, 5.0, 0.05) var lift_speed := 0.45
## How much of its speed it loses per second, so the throw eases into a drift.
@export_range(0.0, 10.0, 0.1) var drag := 1.2
## How fast it tumbles, in radians per second.
@export_range(0.0, 30.0, 0.5) var spin_speed := 3.5
## Seconds it flies before it shrinks away, and the seconds the shrink takes.
@export_range(0.0, 10.0, 0.1) var flight_seconds := 4.0
@export_range(0.05, 2.0, 0.05) var shrink_seconds := 0.35
## How loud the scream starts, from 0 to 1, and the seconds it takes to fade out.
@export_range(0.0, 1.0, 0.05) var scream_volume := 0.3
@export_range(0.1, 5.0, 0.05) var scream_fade_seconds := 1.6

var _velocity := Vector3.ZERO
var _spin_axis := Vector3.RIGHT
var _spin := 0.0
var _vanish: Tween
var _scream_fade: Tween


## Throws the figure out of a door at [param from] (global space), along [param out], the
## way out of it, in [param color].
func throw(from: Vector3, out: Vector3, color: Color) -> void:
	global_position = from
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"color", color)
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material
	var side := out.cross(Vector3.UP).normalized()
	_velocity = out * throw_speed + Vector3.UP * lift_speed + side * randf_range(-0.15, 0.15)
	var axis := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	_spin_axis = axis.normalized() if axis.length_squared() > 0.01 else Vector3.RIGHT
	_spin = 0.0 if Settings.reduce_motion else spin_speed * (1.0 if randf() < 0.5 else -1.0)
	if _vanish:
		_vanish.kill()
	_vanish = create_tween()
	_vanish.tween_interval(flight_seconds)
	(
		_vanish
		. tween_property(self, ^"scale", Vector3.ONE * 0.01, shrink_seconds)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	_vanish.tween_callback(queue_free)
	_scream()


# Plays the scream on the figure's own player, so it can fade without touching the shared
# sound effects. It fades fastest at first, as a sound does flying away.
func _scream() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = SCREAM
	player.bus = Audio.BUS_NAMES[Audio.Bus.SFX]
	player.volume_linear = scream_volume
	add_child(player)
	player.play()
	if _scream_fade:
		_scream_fade.kill()
	_scream_fade = create_tween()
	(
		_scream_fade
		. tween_property(player, ^"volume_linear", 0.0, scream_fade_seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func _process(delta: float) -> void:
	global_position += _velocity * delta
	_velocity *= exp(-drag * delta)
	if _spin != 0.0:
		rotate(_spin_axis, _spin * delta)
