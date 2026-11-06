@tool
class_name SpaceSky
extends WorldEnvironment
## A procedural space background: near-black, with faint coloured fog and stars.
## Add it as a node in place of a WorldEnvironment and change its look from the
## inspector or from code, such as a red mood over two seconds:
## [code]space_sky.fade_to(Color(0.08, 0.02, 0.03), Color(0.1, 0.05, 0.0), 2.0)[/code].
## It builds its own [Environment] and doesn't save it into the scene.
## Each export but [member ambient_color] sets the shader uniform of the same name, and
## holds the only default for it.

const SHADER := preload("res://game/space_sky/space_sky.gdshader")

## The empty space between the fog.
@export var background_color := Color(0.004, 0.005, 0.011):
	set(value):
		background_color = value
		_set_param(&"background_color", value)
## The main fog tint. Sets the mood; keep it dark, the shader only adds it on top.
@export var fog_color := Color(0.03, 0.06, 0.13):
	set(value):
		fog_color = value
		_set_param(&"fog_color", value)
## A second, smaller fog tint that varies the colour.
@export var fog_accent_color := Color(0.07, 0.03, 0.09):
	set(value):
		fog_accent_color = value
		_set_param(&"fog_accent_color", value)
## How strongly both fog tints show. 0 is plain background and stars.
@export_range(0.0, 2.0) var fog_strength := 1.0:
	set(value):
		fog_strength = value
		_set_param(&"fog_strength", value)
@export var star_color := Color(0.9, 0.95, 1.0):
	set(value):
		star_color = value
		_set_param(&"star_color", value)
@export_range(0.0, 4.0) var star_brightness := 1.5:
	set(value):
		star_brightness = value
		_set_param(&"star_brightness", value)
## The light on 3D objects. The sky doesn't light them, so changing the fog is cheap.
@export var ambient_color := Color(0.35, 0.37, 0.45):
	set(value):
		ambient_color = value
		environment.ambient_light_color = value

var _material := ShaderMaterial.new()
var _fade: Tween


func _init() -> void:
	_material.shader = SHADER
	var sky := Sky.new()
	sky.sky_material = _material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Sky-based light would re-render the radiance map whenever the fog changes.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment = env
	# Runs every export's setter, so each default reaches the shader or the Environment.
	# Read from the script, so a new export can't be left out of a list.
	for property: Dictionary in (get_script() as Script).get_script_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			set(property.name, get(property.name))


## Blends the fog to new colours over [param duration] seconds.
## Outside the tree, or with no duration, it sets them at once.
func fade_to(new_fog_color: Color, new_accent_color: Color, duration := 1.0) -> void:
	if _fade:
		_fade.kill()
	if not is_inside_tree() or duration <= 0.0:
		fog_color = new_fog_color
		fog_accent_color = new_accent_color
		return
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_fade.tween_property(self, ^"fog_color", new_fog_color, duration)
	_fade.tween_property(self, ^"fog_accent_color", new_accent_color, duration)


func _validate_property(property: Dictionary) -> void:
	# The Environment is rebuilt in _init, so saving it would only add noise to the scene.
	if property.name == "environment":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _set_param(param: StringName, value: Variant) -> void:
	_material.set_shader_parameter(param, value)
