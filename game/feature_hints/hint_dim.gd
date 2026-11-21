class_name HintDim
extends ColorRect
## The dim under a feature hint: dark navy over the whole screen but a rounded hole round
## the hint's [member target], whose edge sits under the target's [GuideRing]. It sits over
## the HUD and under the guide cards, and takes no clicks.
## [method fade_in] and [method fade_out] ease it in and out from where it is, also under
## Reduce motion. A new [member target] while it shows glides the hole over to it, or
## moves it at once under Reduce motion. It works while the game is paused.

const SHADER := preload("res://game/feature_hints/hint_dim.gdshader")
const COLOR := Color(0.078, 0.071, 0.188, 0.6)
## Seconds it takes to fade in, and to fade out: as the music muffles and clears.
const IN_SECONDS := 0.4
const OUT_SECONDS := 0.6
## Seconds the hole takes to glide to a new target.
const GLIDE_SECONDS := 0.35
## Pixels from the target's edge to the hole's: the middle of the ring's line.
const GROW := GuideRing.GAP + GuideRing.OUTLINE + GuideRing.LINE * 0.5

## What the hole shows. It follows the target as it moves.
var target: Control:
	set(value):
		target = value
		_from = _hole
		_glide = 1.0
		if visible and not Settings.reduce_motion:
			_glide = 0.0
			if _gliding:
				_gliding.kill()
			_gliding = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			_gliding.tween_property(self, ^"_glide", 1.0, GLIDE_SECONDS)

# The hole, in the dim's own pixels, and the one it glides from.
var _hole := Rect2()
var _from := Rect2()
# How far the hole has glided from _from to its target, 0 to 1.
var _glide := 1.0
var _gliding: Tween
var _fade: Tween


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 9
	color = COLOR
	modulate.a = 0.0
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material
	hide()
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		var rect := target.get_global_rect().grow(GROW)
		_hole = Rect2(
			_from.position.lerp(rect.position, _glide), _from.size.lerp(rect.size, _glide)
		)
	var half := _hole.size * 0.5
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter(&"size", size)
	shader_material.set_shader_parameter(&"hole_center", _hole.get_center() - global_position)
	shader_material.set_shader_parameter(&"hole_half", half)
	shader_material.set_shader_parameter(
		&"radius", minf(GuideRing.CORNER + GROW, minf(half.x, half.y))
	)


## Eases the dim in round [member target].
func fade_in() -> void:
	show()
	set_process(true)
	_process(0.0)
	_fade_to(1.0, IN_SECONDS, Tween.EASE_OUT)


## Eases the dim out, still following [member target].
func fade_out() -> void:
	# Its scene may be leaving the tree, where nothing can tween.
	if not is_inside_tree():
		return
	_fade_to(0.0, OUT_SECONDS, Tween.EASE_IN_OUT)
	_fade.tween_callback(_on_faded_out)


func _fade_to(alpha: float, seconds: float, ease_type: Tween.EaseType) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	_fade.tween_property(self, ^"modulate:a", alpha, seconds)


func _on_faded_out() -> void:
	hide()
	set_process(false)
