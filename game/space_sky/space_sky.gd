@tool
class_name SpaceSky
extends WorldEnvironment
## A procedural space background: near-black, with faint coloured fog and stars.
## Add it as a node in place of a WorldEnvironment and change its look from the
## inspector or from code, such as a red mood over two seconds:
## [code]space_sky.fade_to(Color(0.08, 0.02, 0.03), Color(0.1, 0.05, 0.0), 2.0)[/code].
## It builds its own [Environment] and doesn't save it into the scene.
## A camera that pans or zooms without turning wants [member parallax] on; one that turns
## wants it off.
## Each export but [member ambient_color] sets the shader uniform of the same name, and
## holds the only default for it.

const SHADER := preload("res://game/space_sky/space_sky.gdshader")
## Draws the parallax layers with the fog read from a [SpaceFogMap], which costs a
## fraction of working the fog out per pixel. The game's sky uses it; the editor keeps
## [constant SHADER], which needs no camera to tell it what is in view.
const LAYERS_SHADER := preload("res://game/space_sky/space_sky_layers.gdshader")
## The shaders' FOG_DEPTH and FOG_SCALE (space_sky.gdshaderinc): how many parallax depths
## away the fog layer sits, and how many units of fog one depth spans.
const FOG_DEPTH := 4.0
const FOG_SCALE := 2.2
## How much wider than the camera's view the part of the fog layer asked of the map is.
const FOG_VIEW_GROWTH := 1.04
## The part of the fog layer the map holds before a camera says what is in view.
const FOG_START_VIEW := Rect2(-2.0, -1.0, 4.0, 2.0)
## The shaders' MAX_STAR_COVERS (space_sky.gdshaderinc): how many [member star_covers] the
## sky hides its stars behind.
const MAX_STAR_COVERS := 4

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
## Lays the fog and stars on flat layers far behind the scene, facing the camera, so a
## camera that pans or zooms slides them, the farthest the slowest. Off, they sit on the sky
## sphere and move only when the camera turns. Reduce motion holds the layers still.
## The layers face the current camera's angle, so a camera that turns with it on sees
## them swing with it.
@export var parallax := false:
	set(value):
		parallax = value
		_set_param(&"parallax", value)
		set_process(value)
		_pick_shader()
## How far past the world origin, in world units, the nearest star layer sits; the farther
## stars sit at twice that and the fog at four times. Nearer layers slide faster.
@export_range(10.0, 5000.0, 1.0, "or_greater") var parallax_depth := 1000.0:
	set(value):
		parallax_depth = value
		_set_param(&"parallax_depth", value)
## Degrees a second the near star layer drifts to the screen's right, as the main menu's
## stars do; the far layer drifts at 0.375 of it. Only with [member parallax] on, and held
## still under Reduce motion. 0 keeps them put.
@export_range(-5.0, 5.0, 0.01) var star_drift := 0.0:
	set(value):
		star_drift = value
		_set_param(&"star_drift", value)
## The light on 3D objects. The sky doesn't light them, so changing the fog is cheap.
@export var ambient_color := Color(0.35, 0.37, 0.45):
	set(value):
		ambient_color = value
		environment.ambient_light_color = value

## Billboards the sky's stars hide behind, such as a star's see-through halo, which would
## otherwise let them shine through it. The first [constant MAX_STAR_COVERS] count; hidden
## ones hide nothing. Each covers the disc its mesh's width spans, facing the camera.
var star_covers: Array[MeshInstance3D] = []

var _material := ShaderMaterial.new()
# The fog layer as a texture, while LAYERS_SHADER draws the sky.
var _fog_map: SpaceFogMap
var _fade: Tween
# How far the camera moved while Reduce motion held the parallax layers still.
var _held_back := Vector3.ZERO
var _last_camera_position := Vector3.ZERO
var _has_last_camera_position := false
# Seconds the stars have drifted for: the time in play outside Reduce motion.
var _drift_seconds := 0.0


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
	# Linear shows a flat colour as picked; AgX desaturates bright ones, which dulls the
	# cartoon palette.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment = env
	# Runs every export's setter, so each default reaches the shader or the Environment.
	for property: String in get_export_names():
		set(property, get(property))


func _ready() -> void:
	# Godot turns processing on at ready for any script with _process.
	set_process(parallax)


func _process(delta: float) -> void:
	if star_drift != 0.0 and not _motion_reduced():
		_drift_seconds += delta
		ShaderValues.show(_material, &"star_drift_seconds", _drift_seconds)
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var camera_position := camera.global_position
	ShaderValues.show(_material, &"star_covers", _get_star_covers(camera_position))
	# Under Reduce motion the layers move with the camera, so they hold still on screen.
	# Keeping the camera's movement since then, rather than freezing its position, stops
	# the layers jumping when the setting changes.
	if _has_last_camera_position and _motion_reduced():
		_held_back += camera_position - _last_camera_position
	_last_camera_position = camera_position
	_has_last_camera_position = true
	var layer_position := camera_position - _held_back
	var layer_basis := camera.global_basis.orthonormalized()
	ShaderValues.show(_material, &"camera_position", layer_position)
	ShaderValues.show(_material, &"camera_basis", layer_basis)
	if _fog_map:
		_show_fog(_get_fog_view(camera.get_camera_projection(), layer_position, layer_basis))


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


# Each of the star covers as the shader takes it: the way to it from [param at], and the
# angle in radians its disc spans from there to its edge. Hidden ones and empty slots span
# none.
func _get_star_covers(at: Vector3) -> PackedVector4Array:
	var covers := PackedVector4Array()
	covers.resize(MAX_STAR_COVERS)
	covers.fill(Vector4.ZERO)
	for i: int in mini(star_covers.size(), MAX_STAR_COVERS):
		var cover := star_covers[i]
		if not is_instance_valid(cover) or not cover.is_visible_in_tree() or not cover.mesh:
			continue
		var to := cover.global_position - at
		var distance := to.length()
		if distance <= 0.0:
			continue
		var radius := cover.mesh.get_aabb().size.x * 0.5 * cover.global_basis.x.length()
		var way := to / distance
		covers[i] = Vector4(way.x, way.y, way.z, atan(radius / distance))
	return covers


# The game's parallax sky reads its fog from a map; any other sky works it out per pixel.
func _pick_shader() -> void:
	var layers := parallax and not Engine.is_editor_hint()
	_material.shader = LAYERS_SHADER if layers else SHADER
	if layers and not _fog_map:
		_fog_map = SpaceFogMap.new()
		add_child(_fog_map, false, INTERNAL_MODE_BACK)
		_set_param(&"fog_map", _fog_map.get_texture())
		_show_fog(FOG_START_VIEW)


# Has the map hold [param view] of the fog layer, and tells the shader what it holds.
func _show_fog(view: Rect2) -> void:
	var held := _fog_map.cover(view)
	ShaderValues.show(_material, &"fog_map_origin", held.position)
	ShaderValues.show(_material, &"fog_map_span", held.size)


# The part of the fog layer a camera with [param projection] sees from [param at], facing
# along [param basis], in the layer's units: where the shader's fog_layer_point() lands
# for the corners of the screen, and a little past them.
func _get_fog_view(projection: Projection, at: Vector3, basis: Basis) -> Rect2:
	var fog_depth := parallax_depth * FOG_DEPTH
	var along := fog_depth - at.dot(-basis.z)
	# The view ray through a corner, as the sky shader builds it, per unit of depth.
	var low := Vector2(projection.z.x - 1.0, projection.z.y - 1.0)
	var high := Vector2(projection.z.x + 1.0, projection.z.y + 1.0)
	var reach := Vector2(projection.x.x, projection.y.y)
	var middle := Vector2(at.dot(basis.x), at.dot(basis.y))
	var seen := Rect2(middle + low / reach * along, (high - low) / reach * along).abs()
	var view := Rect2(seen.position * FOG_SCALE / fog_depth, seen.size * FOG_SCALE / fog_depth)
	return view.grow_individual(
		view.size.x * (FOG_VIEW_GROWTH - 1.0) * 0.5,
		view.size.y * (FOG_VIEW_GROWTH - 1.0) * 0.5,
		view.size.x * (FOG_VIEW_GROWTH - 1.0) * 0.5,
		view.size.y * (FOG_VIEW_GROWTH - 1.0) * 0.5
	)


## The name of every export, read from this script so no list can miss one.
func get_export_names() -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in (get_script() as Script).get_script_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			names.append(property.name)
	return names


func _validate_property(property: Dictionary) -> void:
	# The Environment is rebuilt in _init, so saving it would only add noise to the scene.
	if property.name == "environment":
		property.usage &= ~PROPERTY_USAGE_STORAGE


# The Settings autoload doesn't run in the editor.
func _motion_reduced() -> bool:
	return not Engine.is_editor_hint() and Settings.reduce_motion


func _set_param(param: StringName, value: Variant) -> void:
	_material.set_shader_parameter(param, value)
