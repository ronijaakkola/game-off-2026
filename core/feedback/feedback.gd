extends Node
## Game feel effects. Callers never check Reduce motion: each effect decides inside.
## It owns the current camera's [member Camera3D.h_offset] and [member Camera3D.v_offset],
## so game cameras keep them at 0. It pauses with the game, so a shake freezes under the
## pause menu and finishes after Resume.

## Seconds a full shake takes to fade out.
const FADE := 0.5
## Largest noise offset in metres, at full trauma.
const NOISE := 0.15
## Largest push along the direction in metres, at full trauma. Larger than [constant NOISE],
## so the push always shows through the noise.
const PUSH := 0.25
## How fast the noise moves: roughly its wiggles per second.
const NOISE_FREQUENCY := 15.0

var _trauma := 0.0
var _direction := Vector2.ZERO
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.frequency = NOISE_FREQUENCY
	get_tree().scene_changed.connect(_on_scene_changed)


## Shakes the camera. [param amount] adds to the trauma, which is capped at 1 and fades
## over [constant FADE] seconds; the shake grows with trauma squared, so fast calls stack.
## [param direction] is in screen space ([code]Vector2.DOWN[/code] pushes the camera down)
## and only its direction counts. The latest call's direction applies to the rest of the
## shake. Does nothing when Reduce motion is on.
func shake(amount: float, direction := Vector2.ZERO) -> void:
	if Settings.reduce_motion:
		return
	_trauma = minf(_trauma + amount, 1.0)
	_direction = direction.normalized()


func _process(delta: float) -> void:
	if _trauma == 0.0:
		return
	_trauma = maxf(_trauma - delta / FADE, 0.0)
	_time += delta
	var noise := Vector2(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(0.0, _time))
	# Reaches zero on the frame trauma does, which puts the camera back.
	_set_offset((noise * NOISE + _direction * PUSH) * _trauma * _trauma)


func _on_scene_changed() -> void:
	_trauma = 0.0
	_set_offset(Vector2.ZERO)


func _set_offset(offset: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()  # null between scenes and in menus.
	if camera == null:
		return
	camera.h_offset = offset.x
	camera.v_offset = -offset.y  # Screen space points down, the camera's up points up.
