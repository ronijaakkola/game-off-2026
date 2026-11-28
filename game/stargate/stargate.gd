class_name Stargate
extends Node3D
## The stargate The Boss has built beside [member planet], which the bus goes through from
## one star to another: a ring of dark hull with pale clamps and amber lamps round an
## opening that glows. Until it is [member built] it isn't there; [method appear] builds it
## as the player watches, and the other systems' are there from then on
## ([method build_all]). It keeps beside the planet as it orbits, on the side away from the
## star as a warp gate does, further out, and turns slowly. Its hull is lit as the planets
## are, from its planet's star.

## The group every stargate is in, so the game can find it.
const GROUP := &"stargates"
const SHADER := preload("res://shared/two_tone.gdshader")
## How far from the planet's centre it floats, in units, and how far out its edge reaches
## from there.
const DISTANCE := 1.7
const RADIUS := 0.55
## Seconds per turn about its own axis, as a wheel turns.
const TURN_SECONDS := 30.0
## How far the ring, which stands upright, leans back, so the camera above sees it open.
const LEAN_DEGREES := 35.0
## The soft glow round its opening: its size in units and its colour.
const GLOW_SIZE := 1.8
const GLOW_COLOR := Color(0.35, 0.85, 1.0, 0.5)
## The parts that give light, by the end of their mesh's name, and the opening.
const LIT_PARTS: Array[String] = ["Lamps", "Inner"]
const CORE_PART := "Core"
const LAMP_COLOR := Color(1.0, 0.78, 0.38)
const CORE_COLOR := Color(0.45, 0.9, 1.0, 0.75)
## Appearing: seconds the ring takes to grow in, spinning down from this many turns. Then
## its opening flickers on, lit then dark in turn for these seconds, as a tube that flickers
## before it catches, and settles from a flash over [constant LIGHT_SECONDS].
const GROW_SECONDS := 1.6
const GROW_TURNS := 1.5
const FLICKER: Array[float] = [0.05, 0.16, 0.07, 0.1, 0.04, 0.22]
const LIGHT_SECONDS := 0.9
## How much brighter than at rest the opening flashes as it lights.
const FLASH := 2.2

## The planet it floats beside.
@export var planet: Planet

## Whether it has been built, and so shows.
var built := false:
	set(value):
		built = value
		visible = value

var _hull: Array[ShaderMaterial] = []
var _core := StandardMaterial3D.new()
var _glow := StandardMaterial3D.new()
var _appearing: Tween


## The stargate in [param tree] that floats in [param system], or null without one.
static func find(tree: SceneTree, system: StarSystem) -> Stargate:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var gate := node as Stargate
		if gate.planet and system.has_planet(gate.planet):
			return gate
	return null


## Every stargate in [param tree] is there, as the first one is once it is built.
static func build_all(tree: SceneTree) -> void:
	for node: Node in tree.get_nodes_in_group(GROUP):
		(node as Stargate).built = true


func _ready() -> void:
	add_to_group(GROUP)
	visible = built
	(%Lean as Node3D).rotation_degrees.x = -LEAN_DEGREES
	_dress()


func _process(delta: float) -> void:
	if not planet:
		return
	var body := planet.get_body_global_position()
	# The planet's star system tells the planet where its star is every frame.
	var star := planet.light_source
	var out := Vector3(body.x - star.x, 0.0, body.z - star.z).normalized()
	global_position = body + out * DISTANCE
	(%Spin as Node3D).rotate_object_local(Vector3.BACK, TAU * delta / TURN_SECONDS)
	for material: ShaderMaterial in _hull:
		ShaderValues.show(material, &"light_source", star)


## Builds it as the player watches: the ring grows out of nothing, spinning down, then its
## opening flickers on and flashes. It returns once it is there. Under Reduce motion it is
## there at once.
func appear() -> void:
	built = true
	if _appearing:
		_appearing.kill()
	if Settings.reduce_motion:
		return
	var spin := %Spin as Node3D
	spin.scale = Vector3.ONE * 0.001
	_set_glow(0.0)
	_appearing = create_tween()
	_appearing.set_parallel()
	(
		_appearing
		. tween_property(spin, ^"scale", Vector3.ONE, GROW_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_appearing
		. tween_method(_set_turn.bind(spin.rotation.z), GROW_TURNS * TAU, 0.0, GROW_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_appearing.set_parallel(false)
	for i: int in FLICKER.size():
		_appearing.tween_callback(_set_glow.bind(1.0 if i % 2 == 0 else 0.0))
		_appearing.tween_interval(FLICKER[i])
	_appearing.tween_method(_set_glow, FLASH, 1.0, LIGHT_SECONDS)
	await _appearing.finished


# How far the ring has yet to turn before it rests at [param rest], while it grows in.
func _set_turn(left: float, rest: float) -> void:
	(%Spin as Node3D).rotation.z = rest - left


# How bright the opening is, 1 at rest.
func _set_glow(amount: float) -> void:
	_core.albedo_color = Color(CORE_COLOR, minf(CORE_COLOR.a * amount, 1.0))
	_glow.albedo_color = Color(GLOW_COLOR, minf(GLOW_COLOR.a * amount, 1.0))


# The model's hull in the planets' two-tone light, its lamps flat and bright, and its
# opening see-through and glowing.
func _dress() -> void:
	_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core.cull_mode = BaseMaterial3D.CULL_DISABLED
	_core.albedo_color = CORE_COLOR
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = LAMP_COLOR
	for node: Node in %Model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var part_name := String(part.name)
		if part_name.ends_with(CORE_PART):
			part.material_override = _core
		elif LIT_PARTS.any(func(end: String) -> bool: return part_name.ends_with(end)):
			part.material_override = lamp
		else:
			var imported := part.mesh.surface_get_material(0) as BaseMaterial3D
			var flat := ShaderMaterial.new()
			flat.shader = SHADER
			flat.set_shader_parameter(&"color", imported.albedo_color)
			part.material_override = flat
			_hull.append(flat)
	# A soft round glow that always faces the camera, adding light to what is behind it.
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_texture = texture
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * GLOW_SIZE
	quad.material = _glow
	(%Glow as MeshInstance3D).mesh = quad
	_set_glow(1.0)
