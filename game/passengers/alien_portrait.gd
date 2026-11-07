class_name AlienPortrait
extends Node3D
## A passenger's bust: one of the alien head models, redrawn with the planets' two-tone
## light in a skin and an outfit colour, with eyes drawn on its Eye markers that blink
## and look around, and a slow idle sway. Stalk parts wobble behind the head. Asleep, the
## eyes shut and the head nods forward; on a moving bus, the bust leans with the push it
## feels and sways back.

const BODY_SHADER := preload("res://shared/two_tone.gdshader")
const EYE_SHADER := preload("res://game/passengers/alien_eye.gdshader")
# The models' material names, recoloured here.
const SKIN_MATERIAL := "AlienSkin"
const OUTFIT_MATERIAL := "AlienOutfit"
# Model nodes are named after their head shape, such as DomeHead and BlobEye.
const HEAD_SUFFIX := "Head"
const EYE_PART := "Eye"
const STALK_PART := "Stalk"
## How fast the eyes shut as they fall asleep, and open as they wake, per second.
const SLEEP_SPEED := 0.8
const WAKE_SPEED := 4.0
## How far the head leans, in radians, per unit per second squared of push felt.
const LURCH_GAIN := 0.07
## The lean's spring: how hard it pulls back to where the push holds it, and how fast its
## swing dies down. A sudden push overshoots a little and sways back.
const LURCH_STIFFNESS := 60.0
const LURCH_DAMPING := 5.0
## How much more a forward or backward push leans the head than a sideways one. The
## camera faces them, so a lean toward it barely shows unless it is bigger.
const FORWARD_LURCH := 2.0
## A forward lean also dips the head and brings it closer, which shows head on: how far
## it drops, in the model's units, and how much bigger it looks, per radian of lean.
const FORWARD_DIP := 0.12
const FORWARD_GROW := 0.25
## The furthest the head leans, in radians.
const LURCH_MAX := 0.6
## How much of the lean the whole bust takes; the head takes all of it.
const BODY_LURCH := 0.35

## One of the head models in `models/`.
@export var head_model: PackedScene
@export var skin_color := Color(0.3, 0.8, 0.7):
	set(value):
		skin_color = value
		_body_material(SKIN_MATERIAL).set_shader_parameter(&"color", value)
		_eye_material.set_shader_parameter(&"lid_color", value)
@export var outfit_color := Color(0.42, 0.36, 0.7):
	set(value):
		outfit_color = value
		_body_material(OUTFIT_MATERIAL).set_shader_parameter(&"color", value)
## How the eyes are drawn. Without one, they are the shader's plain cartoon eyes.
@export var eye_style: AlienEyeStyle:
	set(value):
		eye_style = value
		if value:
			value.apply(_eye_material)
## How far the eyes open at rest: 1 wide awake, lower for a drowsy or sullen look.
@export_range(0.0, 1.0) var eye_openness := 1.0
## Whether they are asleep: the eyes drift shut and stop blinking and wandering, and the
## head nods forward and breathes slower. A startle still opens the eyes for a moment.
@export var asleep := false
## The push they feel on the bus, in units per second squared: +x toward their own right
## (the camera's left, since they face it) and +y forward, toward the camera. The bust
## leans with it on a spring, so a jolt makes it sway.
var felt_acceleration := Vector2.ZERO

## The eyes, made on the model's Eye markers.
var eyes: Array[MeshInstance3D] = []

var _materials: Dictionary[String, ShaderMaterial] = {}
var _eye_material := ShaderMaterial.new()
var _model: Node3D
var _model_rest := Vector3.ZERO
var _head: Node3D
var _head_rest := Vector3.ZERO
var _stalks: Array[Node3D] = []
var _stalk_rest: Array[Vector3] = []
var _time := 0.0
# Each portrait moves on its own timing.
var _phase := randf() * TAU
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _look_hold := 0.0
var _blink_in := 0.0
var _blink := 0.0
var _blinking: Tween
var _startle := 0.0
var _startling: Tween
# How far asleep, from 0 awake to 1 eyes shut, and which way the head tilts as it nods.
var _sleep := 0.0
var _sleep_side := 1.0 if randf() < 0.5 else -1.0
var _breath := 0.0
# The lean from the push felt, in radians (+x toward their right, +y forward), and how
# fast it swings.
var _lurch := Vector2.ZERO
var _lurch_velocity := Vector2.ZERO


func _ready() -> void:
	_eye_material.shader = EYE_SHADER
	var model := head_model.instantiate() as Node3D
	add_child(model)
	_model = model
	_model_rest = model.rotation
	for node: Node in model.find_children("*", "Node3D", true, false):
		var part := node as Node3D
		if part is MeshInstance3D:
			_recolour(part as MeshInstance3D)
		if part.name.contains(EYE_PART):
			_add_eye(part)
		elif part.name.ends_with(HEAD_SUFFIX):
			_head = part
			_head_rest = part.position
		elif part.name.contains(STALK_PART):
			_stalks.append(part)
			_stalk_rest.append(part.rotation)
	if not _head:
		push_error(
			(
				"%s has no part named *%s: it won't sway, and is framed whole"
				% [head_model.resource_path, HEAD_SUFFIX]
			)
		)
	skin_color = skin_color
	outfit_color = outfit_color
	eye_style = eye_style
	_blink_in = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	_time += delta
	var motion := 0.0 if Settings.reduce_motion else 1.0
	_sleep = move_toward(
		_sleep, 1.0 if asleep else 0.0, delta * (SLEEP_SPEED if asleep else WAKE_SPEED)
	)
	if asleep:
		# Closed eyes rest looking a little down, and don't blink.
		_look_target = Vector2(0.0, -0.4)
		_look_hold = 0.5
		_blink_in = maxf(_blink_in, 0.5)
	_wander_gaze(delta)
	_look = _look.lerp(_look_target, 1.0 - exp(-12.0 * delta))
	_blink_in -= delta
	if _blink_in <= 0.0:
		blink()
		_blink_in = randf_range(2.0, 5.5)
	_sway_with_push(delta)

	var t := _time + _phase
	var lurch := _lurch * motion
	if _model:
		_model.rotation = _model_rest + Vector3(lurch.y, 0.0, lurch.x) * BODY_LURCH
	if _head:
		# Asleep, they breathe slower and deeper.
		_breath += delta * lerpf(1.6, 1.0, _sleep)
		var breath := sin(_breath + _phase) * lerpf(0.018, 0.03, _sleep) * motion
		var grow := 1.0 + lurch.y * FORWARD_GROW
		_head.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0 - breath * 0.5) * grow
		# The head turns a little toward where the eyes look, nods forward asleep, and leans
		# with the push the bust doesn't take.
		var nod := Vector2(_sleep_side * 0.1, 0.16) * _sleep * motion
		var lean := nod + lurch * (1.0 - BODY_LURCH)
		_head.rotation = Vector3(
			sin(t * 0.7) * 0.04 * motion - _look.y * 0.08 - _startle * 0.12 * motion + lean.y,
			_look.x * 0.18,
			sin(t * 0.9 + 1.3) * 0.05 * motion + lean.x,
		)
		var lift := _startle * 0.02 * motion - lurch.y * FORWARD_DIP
		_head.position = _head_rest + Vector3.UP * lift
	for i: int in _stalks.size():
		# Stalks trail behind a swing of the head.
		var wobble := Vector3(
			sin(t * 2.1 + i * 2.0) * 0.07 + _lurch_velocity.y * 0.06,
			0.0,
			(
				sin(t * 1.7 + i * 1.3) * 0.09
				+ sin(_time * 22.0 + i) * _startle * 0.3
				+ _lurch_velocity.x * 0.06
			),
		)
		_stalks[i].rotation = _stalk_rest[i] + wobble * motion

	var open := lerpf(eye_openness, 0.0, _sleep) * (1.0 - _blink)
	_eye_material.set_shader_parameter(&"open", lerpf(open, 1.0, _startle))
	_eye_material.set_shader_parameter(&"look", _look)
	for eye: MeshInstance3D in eyes:
		eye.scale = Vector3.ONE * (1.0 + _startle * 0.25)


## The bounds of the head and what is on it, such as stalks and eyes, in this node's
## space. A shape that is all one piece, such as the Bean, gives its whole body, and so
## does a model with no head part.
func get_head_bounds() -> AABB:
	var parts: Array[Node] = []
	if _head:
		parts = _head.find_children("*", "MeshInstance3D", true, false)
		parts.append(_head)
	else:
		parts = find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	for node: Node in parts:
		var mesh := node as MeshInstance3D
		var local := global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds


## Points the eyes toward [param direction], from -1 to 1 on each axis (+y up), and holds
## them there for a while before they wander again.
func look_toward(direction: Vector2) -> void:
	_look_target = direction.limit_length(1.0)
	_look_hold = 1.5


## Shuts the eyes for a moment.
func blink() -> void:
	if _blinking:
		_blinking.kill()
	_blinking = create_tween()
	_blinking.tween_property(self, "_blink", 1.0, 0.07)
	_blinking.tween_property(self, "_blink", 0.0, 0.1)


## A start of surprise: the eyes go wide and the head jerks back, then settle.
func startle() -> void:
	if _startling:
		_startling.kill()
	_startling = create_tween()
	_startling.tween_property(self, "_startle", 1.0, 0.06)
	_startling.tween_property(self, "_startle", 0.0, 0.8).set_trans(Tween.TRANS_ELASTIC)
	_blink_in = maxf(_blink_in, 1.0)


# The lean follows the push on a spring: the push holds it at a lean, and when the push
# stops it swings back past upright and settles.
func _sway_with_push(delta: float) -> void:
	var rest := felt_acceleration * LURCH_GAIN * Vector2(1.0, FORWARD_LURCH)
	var pull := (rest - _lurch) * LURCH_STIFFNESS - _lurch_velocity * LURCH_DAMPING
	_lurch_velocity += pull * delta
	_lurch += _lurch_velocity * delta
	if _lurch.length() > LURCH_MAX:
		_lurch = _lurch.limit_length(LURCH_MAX)
		_lurch_velocity = _lurch_velocity.slide(_lurch.normalized())


func _wander_gaze(delta: float) -> void:
	_look_hold -= delta
	if _look_hold > 0.0:
		return
	# Mostly glance around near the middle, sometimes far off to one side.
	_look_target = Vector2(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3))
	if randf() < 0.2:
		_look_target.x = signf(_look_target.x) * 0.95
	_look_hold = randf_range(1.2, 3.5)


func _recolour(mesh: MeshInstance3D) -> void:
	for surface: int in mesh.mesh.get_surface_count():
		var imported := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
		if not imported:
			# Nothing to recolour from: the surface keeps Godot's default material.
			continue
		var material := _body_material(imported.resource_name)
		if imported.resource_name not in [SKIN_MATERIAL, OUTFIT_MATERIAL]:
			material.set_shader_parameter(&"color", imported.albedo_color)
		mesh.set_surface_override_material(surface, material)


func _body_material(material_name: String) -> ShaderMaterial:
	if not _materials.has(material_name):
		var material := ShaderMaterial.new()
		material.shader = BODY_SHADER
		_materials[material_name] = material
	return _materials[material_name]


func _add_eye(marker: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var eye := MeshInstance3D.new()
	eye.name = "EyeDisc"
	eye.mesh = quad
	eye.material_override = _eye_material
	marker.add_child(eye)
	eyes.append(eye)
