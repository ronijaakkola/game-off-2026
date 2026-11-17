class_name FrameshiftShift
extends Node3D
## A frameshift jump, as the tow ship and the bus make one: [method shift_in] or
## [method shift_out] moves a body along a straight jump in [constant SECONDS] and stretches
## its model long and thin along its heading. Shifting in, it slows into place and shrinks
## back from long and thin; shifting out, it speeds away and stretches out, then the model
## hides. Either way it leaves a flat streak on the orbit plane along the jump, which fades
## once the jump is over. It draws in global space.

## The jump is over: the body is where it was going.
signal finished

## Seconds a jump takes, and how far the tow ship's goes.
const SECONDS := 0.3
const DISTANCE := 2.5
## How long and how thin the model stretches at the jump's far end, as shares of its size.
const STRETCH := 6.0
const THIN := 0.12
## Seconds the streak takes to fade, and how see-through it starts.
const STREAK_FADE_SECONDS := 0.5
const STREAK_OPACITY := 0.85

var _body: Node3D
var _model: Node3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _time := 0.0
var _shifting := false
var _shifting_in := false
# How much of the streak shows, from 1 as a jump ends to 0 once it has faded.
var _streak := 0.0
var _streak_material: StandardMaterial3D


func _ready() -> void:
	var streak := %Streak as MeshInstance3D
	streak.hide()
	# Its own copy, so fading it fades no other jump's.
	_streak_material = (streak.material_override as StandardMaterial3D).duplicate()
	streak.material_override = _streak_material


## Moves the jump and the streak's fade [param delta] seconds on. Its owner calls it every
## frame, so a test can step it with the owner.
func advance(delta: float) -> void:
	_streak = move_toward(_streak, 0.0, delta / STREAK_FADE_SECONDS)
	if _shifting:
		_shift(delta)
	_draw_streak()


## Jumps [param body] in from [param from] to [param to], its [param model] shrinking back
## from long and thin.
func shift_in(body: Node3D, model: Node3D, from: Vector3, to: Vector3) -> void:
	_start(body, model, from, to, true)


## Jumps [param body] out from [param from] to [param to], its [param model] stretching out
## and then hiding.
func shift_out(body: Node3D, model: Node3D, from: Vector3, to: Vector3) -> void:
	_start(body, model, from, to, false)


## Whether a jump is under way.
func is_shifting() -> bool:
	return _shifting


## Whether the streak of the last jump still shows.
func is_streaking() -> bool:
	return _streak > 0.0


func _start(body: Node3D, model: Node3D, from: Vector3, to: Vector3, shifting_in: bool) -> void:
	_body = body
	_model = model
	_from = from
	_to = to
	_time = 0.0
	_shifting = true
	_shifting_in = shifting_in
	_body.global_position = from
	_model.show()
	_stretch(1.0 if shifting_in else 0.0)


func _shift(delta: float) -> void:
	_time += delta
	var done := clampf(_time / SECONDS, 0.0, 1.0)
	# How far along the jump, eased toward its slow end.
	var along := 1.0 - (1.0 - done) * (1.0 - done) if _shifting_in else done * done
	_body.global_position = _from.lerp(_to, along)
	_stretch(1.0 - done if _shifting_in else done)
	_streak = 1.0
	if done < 1.0:
		return
	_shifting = false
	if not _shifting_in:
		_model.hide()
		_stretch(0.0)
	finished.emit()


# Stretches the model along its heading and thins it, by [param amount] from 0 (its own
# shape) to 1 (the far end of a jump).
func _stretch(amount: float) -> void:
	var thin := lerpf(1.0, THIN, amount)
	_model.scale = Vector3(thin, thin, lerpf(1.0, STRETCH, amount))


# The streak from the jump's start to where the body is, or to the jump's end once over.
func _draw_streak() -> void:
	var streak := %Streak as MeshInstance3D
	if not _body:
		streak.hide()
		return
	var end := _body.global_position if _shifting else _to
	var span := _flat(end - _from)
	var length := span.length()
	streak.visible = _streak > 0.0 and length > 1e-3
	if not streak.visible:
		return
	_streak_material.albedo_color.a = _streak * STREAK_OPACITY
	var along := span / length
	# The streak mesh is a plane one unit long along its z.
	var streak_basis := Basis(Vector3.UP.cross(along), Vector3.UP, along * length)
	streak.global_transform = Transform3D(streak_basis, _flat(_from + end) * 0.5)


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
