class_name MenuBackground
extends TextureRect
## The menus' background ([code]panorama.gdshader[/code]): pans to the picture's other half
## for the campaign screen and lets its stars drift. Under Reduce motion the stars hold
## still and the pan cuts.

## Seconds the background takes to pan to the campaign screen's half and back.
const PAN_SECONDS := 0.6

var _material: ShaderMaterial
var _pan: Tween
var _time := 0.0


func _ready() -> void:
	_material = material as ShaderMaterial
	resized.connect(_on_resized)
	_on_resized()


## Pans to the picture's right half for the campaign screen ([param right]), or back.
func pan_to(right: bool) -> void:
	var to := 1.0 if right else 0.0
	if _pan:
		_pan.kill()
	if Settings.reduce_motion:
		_material.set_shader_parameter(&"pan", to)
		return
	_pan = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_pan.tween_property(_material, ^"shader_parameter/pan", to, PAN_SECONDS)


func _process(delta: float) -> void:
	if not Settings.reduce_motion:
		_time += delta
	ShaderValues.show(_material, &"drift", _time)


func _on_resized() -> void:
	if size.y > 0.0:
		_material.set_shader_parameter(&"screen_aspect", size.x / size.y)
		_material.set_shader_parameter(&"screen_height", size.y)
