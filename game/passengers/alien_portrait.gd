class_name AlienPortrait
extends Node3D
## A passenger's bust: one of the alien head models, redrawn with the planets' two-tone
## light in a skin and an outfit colour, with eyes drawn on its Eye markers that blink
## and look around, and a slow idle sway. Stalk parts wobble behind the head. Asleep, the
## eyes shut and the head nods forward; on a moving bus, the bust leans with the push it
## feels and sways back. Angry, the lids slant into a frown over smaller pupils, and past
## halfway a red anger mark pops up on the head, which trembles; joyful, lower lids rise
## so the eyes smile into crescents, and the head bobs. Content, they beam that way now
## and then. The skin never changes colour with mood, since it shows the passenger's
## race. A single eye shows anger with a brow over it and joy as a starry eye over
## blushing cheeks, since any curve cut into it reads as a mouth. Eating or drinking, a
## [PortraitMeal] holds the food up to the face and nods the head. Watching something, a
## [PortraitScreen] lights the face in the screen's shifting colours, the eyes stay on it,
## and now and then they laugh: a joyful face, the head tipped back and bouncing.

const BODY_SHADER := preload("res://shared/two_tone.gdshader")
const EYE_SHADER := preload("res://game/passengers/alien_eye.gdshader")
const ANGER_MARK_SHADER := preload("res://game/passengers/anger_mark.gdshader")
## Toward the light that lights the bust, in world space: above, to the left and in front,
## like a photographer's lamp. Portraits face +z.
const LIGHT_DIRECTION := Vector3(-0.48, 0.6, 0.64)
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
## How big the food is, as a share of the head's width.
const MEAL_SIZE := 0.6
## How fast anger and joy blend in and out, per second.
const EXPRESSION_SPEED := 3.0
## At full anger: how far the lids close, and how big the pupils are.
const ANGRY_OPEN := 0.8
const ANGRY_PUPIL := 0.7
## The anger mark: its size, as a share of the head's (the mean of its width and height),
## and where it sits on the head's upper right, from its middle, as a share of the head's
## size. It grows in past half anger, and pulses: how fast, and by how much of its size.
const ANGER_MARK_SIZE := 0.42
const ANGER_MARK_AT := Vector2(0.3, 0.5)
const ANGER_MARK_PULSE_SPEED := 7.0
const ANGER_MARK_PULSE := 0.12
## At full joy, how big the pupils are, and how far up the eyes look, from -1 to 1.
const JOYFUL_PUPIL := 1.15
const JOYFUL_LOOK := 0.35
## Content, how long each beam lasts, and the wait between them, in seconds: a range each.
const BEAM_SECONDS := Vector2(1.2, 2.0)
const BEAM_WAIT := Vector2(3.0, 7.0)
## Past half anger, the head trembles: how fast, and how far at full anger, in radians.
const TREMBLE_SPEED := 45.0
const TREMBLE := 0.04
## Joyful, the head bobs: how fast, and how high at full joy, in the model's units.
const BOB_SPEED := 9.0
const BOB := 0.03
## The furthest the head leans, in radians.
const LURCH_MAX := 0.6
## How much of the lean the whole bust takes; the head takes all of it.
const BODY_LURCH := 0.35
## How far the quad of an eye in the middle of the face reaches, in eye radii, so it has
## room for the brow and blush the shader draws around it.
const CENTRED_EYE_REACH := 1.6

## One of the head models in `models/`.
@export var head_model: PackedScene
@export var skin_color := Color(0.3, 0.8, 0.7):
	set(value):
		skin_color = value
		_show_skin()
@export var outfit_color := Color(0.42, 0.36, 0.7):
	set(value):
		outfit_color = value
		_body_material(OUTFIT_MATERIAL).set_shader_parameter(&"color", value)
## How the eyes are drawn. Without one, they are the shader's plain cartoon eyes.
@export var eye_style: AlienEyeStyle:
	set(value):
		eye_style = value
		if value:
			for material: ShaderMaterial in _eye_materials:
				value.apply(material)
## How far the eyes open at rest: 1 wide awake, lower for a drowsy or sullen look.
@export_range(0.0, 1.0) var eye_openness := 1.0
## Whether they are asleep: the eyes drift shut and stop blinking and wandering, and the
## head nods forward and breathes slower. A startle still opens the eyes for a moment.
@export var asleep := false
## How angry they look, from 0 calm to 1 furious. The face blends toward it.
@export_range(0.0, 1.0) var anger := 0.0
## How joyful they look, from 0 to 1. The face blends toward it.
@export_range(0.0, 1.0) var joy := 0.0
## Whether they are content: now and then they beam with full joy for a moment, as they
## blink. A partial joy doesn't read at a card's size, so contentment is these moments.
@export var content := false
## What they are eating or drinking, if anything.
@export var action := Need.Action.NONE
## The push they feel on the bus, in units per second squared: +x toward their own right
## (the camera's left, since they face it) and +y forward, toward the camera. The bust
## leans with it on a spring, so a jolt makes it sway.
var felt_acceleration := Vector2.ZERO

## The eyes, made on the model's Eye markers.
var eyes: Array[MeshInstance3D] = []
## The red anger mark on the head, shown past half anger.
var anger_mark: MeshInstance3D

var _materials: Dictionary[String, ShaderMaterial] = {}
# One per eye, since each eye's lid slants its own way in anger.
var _eye_materials: Array[ShaderMaterial] = []
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
# How angry and how joyful the face looks now, blending toward anger and joy.
var _anger := 0.0
var _joy := 0.0
# Seconds until the next beam while content, and seconds left of the current one.
var _beam_in := randf_range(0.5, 3.0)
var _beam_left := 0.0
var _meal: PortraitMeal
var _screen := PortraitScreen.new()


func _ready() -> void:
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
	_add_anger_mark()
	skin_color = skin_color
	outfit_color = outfit_color
	eye_style = eye_style
	if _head:
		_add_meal()
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
	_watch(delta, motion)
	_show_expression(delta)
	if _meal:
		_meal.action = action
		_meal.advance(delta, motion)

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
		if _meal:
			_head.scale *= _meal.squash
		# The head turns a little toward where the eyes look, nods forward asleep, and leans
		# with the push the bust doesn't take.
		var nod := Vector2(_sleep_side * 0.1, 0.16) * _sleep * motion
		var lean := nod + lurch * (1.0 - BODY_LURCH)
		_head.rotation = Vector3(
			sin(t * 0.7) * 0.04 * motion - _look.y * 0.08 - _startle * 0.12 * motion + lean.y,
			_look.x * 0.18,
			sin(t * 0.9 + 1.3) * 0.05 * motion + lean.x,
		)
		if _meal:
			_head.rotation.x += _meal.pitch
		var tremble := _get_fury() * TREMBLE * motion
		_head.rotation.z += sin(_time * TREMBLE_SPEED) * tremble
		# A laugh bounces the head its own way, in place of the joyful bob.
		var bob := absf(sin(t * BOB_SPEED)) * BOB * _joy * (1.0 - _screen.laugh) * motion
		var lift := _startle * 0.02 * motion - lurch.y * FORWARD_DIP + bob + _screen.bounce
		_head.rotation.x += _screen.pitch
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
				+ sin(_time * BOB_SPEED + i) * 0.15 * _joy
			),
		)
		_stalks[i].rotation = _stalk_rest[i] + wobble * motion

	if anger_mark:
		var pulse := 1.0 + sin(_time * ANGER_MARK_PULSE_SPEED) * ANGER_MARK_PULSE * motion
		var grow := ease(_get_fury(), 0.4)
		anger_mark.scale = Vector3.ONE * maxf(grow * pulse, 0.001)
		anger_mark.visible = grow > 0.0

	var open := lerpf(eye_openness, 0.0, _sleep) * lerpf(1.0, ANGRY_OPEN, _anger)
	open *= 1.0 - _blink
	_set_eyes(&"open", lerpf(open, 1.0, _startle))
	var look := _look + Vector2(0.0, JOYFUL_LOOK * _joy)
	if _meal:
		# Eating or drinking, they look down at the food.
		look = look.lerp(Vector2(look.x * 0.3, -0.7), _meal.look_down)
	_set_eyes(&"look", look)
	for eye: MeshInstance3D in eyes:
		eye.scale = Vector3.ONE * (1.0 + _startle * 0.25)


## The bounds of the head and what is on it, such as stalks and eyes, but not the anger
## mark, in this node's space. A shape that is all one piece, such as the Bean, gives its
## whole body, and so does a model with no head part.
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
		if mesh == anger_mark:
			continue
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


# Blends the face toward anger and joy, and shows how far it has got.
func _show_expression(delta: float) -> void:
	_anger = move_toward(_anger, anger, delta * EXPRESSION_SPEED)
	_beam_left -= delta
	if content and not asleep:
		_beam_in -= delta
		if _beam_in <= 0.0:
			_beam_left = randf_range(BEAM_SECONDS.x, BEAM_SECONDS.y)
			_beam_in = _beam_left + randf_range(BEAM_WAIT.x, BEAM_WAIT.y)
	var beaming := content and _beam_left > 0.0
	var target := maxf(1.0 if beaming else joy, _screen.laugh)
	_joy = move_toward(_joy, target, delta * EXPRESSION_SPEED)
	_set_eyes(&"anger", _anger)
	_set_eyes(&"pupil_scale", lerpf(1.0, ANGRY_PUPIL, _anger) * lerpf(1.0, JOYFUL_PUPIL, _joy))
	_set_eyes(&"joy", _joy)


# Watching something, the screen lights the face and sets off laughs, unless they are
# angry or asleep.
func _watch(delta: float, motion: float) -> void:
	var watching := action == Need.Action.WATCH
	if watching != _screen.watching:
		_screen.watching = watching
		_look_hold = 0.0
	_screen.may_laugh = anger < 0.5 and not asleep
	_screen.advance(delta, motion)
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter(&"screen_light", _screen.light)


# The skin colour on the body and the eyelids.
func _show_skin() -> void:
	_body_material(SKIN_MATERIAL).set_shader_parameter(&"color", skin_color)
	_set_eyes(&"lid_color", skin_color)


# How far past half anger they are, from 0 to 1: the anger mark and the tremble.
func _get_fury() -> float:
	return clampf(_anger * 2.0 - 1.0, 0.0, 1.0)


# The anger mark, a quad facing the camera on the head's upper right as the camera sees
# it, on the head so it trembles and leans with it. It goes by the head's own mesh, not
# the stalks or eyes on it, so it sits clear of them. Hidden until they are angry.
func _add_anger_mark() -> void:
	var bounds := _get_head_body_bounds()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (bounds.size.x + bounds.size.y) * 0.5 * ANGER_MARK_SIZE
	var material := ShaderMaterial.new()
	material.shader = ANGER_MARK_SHADER
	material.render_priority = 1
	anger_mark = MeshInstance3D.new()
	anger_mark.mesh = quad
	anger_mark.material_override = material
	anger_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anger_mark.visible = false
	var middle := bounds.get_center()
	var offset := Vector2(bounds.size.x, bounds.size.y) * ANGER_MARK_AT
	var at := Vector3(middle.x + offset.x, middle.y + offset.y, bounds.end.z)
	var parent: Node3D = _head if _head else self
	parent.add_child(anger_mark)
	anger_mark.global_position = global_transform * at
	anger_mark.global_basis = global_basis


# The bounds of the head's own mesh in this node's space, without the parts on it, or the
# whole head's when the head part has no mesh of its own.
func _get_head_body_bounds() -> AABB:
	var mesh := _head as MeshInstance3D
	if not mesh:
		return get_head_bounds()
	return global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()


func _set_eyes(parameter: StringName, value: Variant) -> void:
	for material: ShaderMaterial in _eye_materials:
		material.set_shader_parameter(parameter, value)


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
	# Mostly glance around near the middle, sometimes far off to one side. Angry, they
	# glare out of the photo instead.
	_look_target = Vector2(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3))
	if randf() < 0.2:
		_look_target.x = signf(_look_target.x) * 0.95
	_look_target *= 1.0 - _anger * 0.8
	if _screen.watching:
		# Their eyes stay on the screen, in front of them where the camera is.
		_look_target *= 0.15
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
		material.set_shader_parameter(&"light_source", LIGHT_DIRECTION)
		material.set_shader_parameter(&"light_is_directional", true)
		_materials[material_name] = material
	return _materials[material_name]


# The meal goes on the head, in front of where a mouth would be: just below the eyes, since
# the photo crops the bottom of most faces, but within the head for eyes on stalks.
func _add_meal() -> void:
	var bounds := _head_shape_bounds()
	if not bounds.has_volume():
		push_warning("%s's head has no mesh to hold food up to" % head_model.resource_path)
		return
	var width := bounds.size.x
	var mouth_y := bounds.end.y
	for eye: MeshInstance3D in eyes:
		mouth_y = minf(mouth_y, _head.to_local(eye.global_position).y - width * 0.15)
	mouth_y = clampf(mouth_y, bounds.position.y + width * 0.1, bounds.end.y - bounds.size.y * 0.4)
	_meal = PortraitMeal.new()
	_meal.name = "Meal"
	_head.add_child(_meal)
	_meal.setup(Vector3(bounds.get_center().x, mouth_y, bounds.end.z), width * MEAL_SIZE)


# The bounds of the head's own shape in its space, without the eyes: the head part when it
# is a mesh, or else the meshes under it.
func _head_shape_bounds() -> AABB:
	var meshes: Array[Node] = [_head]
	if not _head is MeshInstance3D:
		meshes = _head.find_children("*", "MeshInstance3D", true, false)
	var to_head := _head.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		if mesh in eyes:
			continue
		var local := to_head * mesh.global_transform * mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds


func _add_eye(marker: Node3D) -> void:
	# The camera faces them, so an eye left of the middle has the middle to its right.
	var x := (global_transform.affine_inverse() * marker.global_position).x
	var centred := absf(x) < 0.01
	var reach := CENTRED_EYE_REACH if centred else 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0) * reach
	var material := ShaderMaterial.new()
	material.shader = EYE_SHADER
	material.set_shader_parameter(&"inner_side", 0.0 if centred else -signf(x))
	material.set_shader_parameter(&"reach", reach)
	_eye_materials.append(material)
	var eye := MeshInstance3D.new()
	eye.name = "EyeDisc"
	eye.mesh = quad
	eye.material_override = material
	marker.add_child(eye)
	eyes.append(eye)
