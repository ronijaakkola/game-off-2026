class_name JumpIris
extends CanvasLayer
## The black the jump to the next star system goes through, over everything but the pause
## menu. [method close] closes a circle round a point on screen until the screen is black,
## and [method open] opens one from a point until it is clear again; under Reduce motion
## the black only fades in and out. It takes no clicks.

## The screen is clear again after [method open].
signal opened

## Seconds the circle takes to close, and to open.
const CLOSE_SECONDS := 0.9
const OPEN_SECONDS := 0.9
## Seconds the black takes to fade in or out under Reduce motion.
const FADE_SECONDS := 0.5

var _tween: Tween


func _ready() -> void:
	# Drawn once, clear, so its shader compiles while the scene loads, not as a jump starts.
	_set_radius(INF)
	show()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _tween:
		hide()


## Closes the circle round [param center], in the viewport's coordinates, until the screen
## is black. It returns once it is.
func close(center: Vector2) -> void:
	_begin(center)
	if Settings.reduce_motion:
		_set_radius(0.0)
		_set_opacity(0.0)
		_tween.tween_method(_set_opacity, 0.0, 1.0, FADE_SECONDS)
	else:
		_set_opacity(1.0)
		_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_method(_set_radius, _cover_radius(center), 0.0, CLOSE_SECONDS)
	await _tween.finished


## Starts opening a circle from [param center], in the viewport's coordinates, until the
## screen is clear ([signal opened]).
func open(center: Vector2) -> void:
	_begin(center)
	if Settings.reduce_motion:
		_set_radius(0.0)
		_tween.tween_method(_set_opacity, 1.0, 0.0, FADE_SECONDS)
	else:
		_set_opacity(1.0)
		_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_method(_set_radius, 0.0, _cover_radius(center), OPEN_SECONDS)
	_tween.finished.connect(_on_opened)


func _on_opened() -> void:
	hide()
	opened.emit()


func _begin(center: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var material := _material()
	material.set_shader_parameter(&"center", center)
	material.set_shader_parameter(&"size", (%Cover as Control).size)
	show()


# The radius that leaves the whole screen clear: out to its farthest corner from center.
func _cover_radius(center: Vector2) -> float:
	var end := (%Cover as Control).size
	var farthest := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(end.x, 0.0), Vector2(0.0, end.y), end]:
		farthest = maxf(farthest, center.distance_to(corner))
	return farthest + 1.0


func _set_radius(value: float) -> void:
	_material().set_shader_parameter(&"radius", value if is_finite(value) else 1e6)


func _set_opacity(value: float) -> void:
	_material().set_shader_parameter(&"opacity", value)


func _material() -> ShaderMaterial:
	return (%Cover as CanvasItem).material as ShaderMaterial
