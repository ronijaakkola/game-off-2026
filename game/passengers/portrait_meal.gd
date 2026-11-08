class_name PortraitMeal
extends Node3D
## What a portrait eats or drinks, held up to the face: a snack bar half in its wrapper,
## or a cup with a straw. The aliens have no mouths, so the food covers where one would be
## and the head does the rest. Eating, the bar rises to the face, the head dips to bite
## and then munches; drinking, the cup stays up and the head sips at the straw now and
## then. The [AlienPortrait] it sits in moves its head by [member pitch] and
## [member squash] and looks down by [member look_down].

## How fast the food comes up into view and goes away again, per second.
const SHOW_SPEED := 2.5
## Seconds from one bite to the next, and from one sip to the next.
const BITE_SECONDS := 1.5
const SIP_SECONDS := 1.8
## How far the head dips forward to bite and to sip, in radians.
const BITE_DIP := 0.22
const SIP_DIP := 0.1
## How fast they munch between bites, and how far each chew squashes the head.
const CHEW_SPEED := 14.0
const CHEW := 0.06
## The colours: the bar, its wrapper, the cup, its band and the straw.
const BAR_COLOR := Color(0.86, 0.6, 0.34)
const WRAPPER_COLOR := Color(0.93, 0.33, 0.45)
const CUP_COLOR := Color(0.95, 0.94, 1.0)
const BAND_COLOR := Color(0.36, 0.62, 0.95)
const STRAW_COLOR := Color(0.98, 0.78, 0.25)

## What they act out now. The food changes once the last one is out of view.
var action := Need.Action.NONE
## How far the head dips forward this frame, in radians, for the portrait to add.
var pitch := 0.0
## How the head squashes this frame, as a scale, for the portrait to multiply in.
var squash := Vector3.ONE
## How far the eyes look down at the food, from 0 to 1.
var look_down := 0.0

# Where a mouth would be, in the head's space, and how big the food is.
var _mouth := Vector3.ZERO
var _size := 0.1
var _snack: Node3D
var _drink: Node3D
# What is shown, which lags behind action while the old food goes away.
var _shown := Need.Action.NONE
# How far the food is up, from 0 out of view to 1 at the face.
var _up := 0.0
var _time := 0.0


## Sets the meal up in front of where a mouth would be on the head it is a child of:
## [param mouth] in the head's space, with food about [param size] across.
func setup(mouth: Vector3, size: float) -> void:
	_mouth = mouth
	_size = size
	_snack = _make_snack()
	_drink = _make_drink()
	_show_food()


## Moves the food and works out the head's motion for [param delta] seconds. With
## [param motion] 0, as under Reduce motion, the food comes up and stays still.
func advance(delta: float, motion: float) -> void:
	_time += delta
	if _shown != action:
		_up = move_toward(_up, 0.0, delta * SHOW_SPEED)
		if is_zero_approx(_up):
			_shown = action
			_time = 0.0
			_show_food()
	elif _shown != Need.Action.NONE:
		_up = move_toward(_up, 1.0, delta * SHOW_SPEED)
	var up := ease(_up, -2.0)
	look_down = up
	pitch = 0.0
	squash = Vector3.ONE
	var raise := 0.0
	match _shown:
		Need.Action.EAT:
			# Up to the face, bite, then munch while it goes back down a little.
			var cycle := fmod(_time, BITE_SECONDS) / BITE_SECONDS
			var reach := smoothstep(0.0, 0.25, cycle) * (1.0 - smoothstep(0.3, 0.55, cycle))
			raise = reach * 0.35
			pitch = reach * BITE_DIP
			var chewing := smoothstep(0.3, 0.4, cycle)
			var chew := absf(sin(_time * CHEW_SPEED)) * CHEW * chewing
			squash = Vector3(1.0 + chew * 0.5, 1.0 - chew, 1.0 + chew * 0.5)
		Need.Action.DRINK:
			# Held still at the straw; every so often a long sip pulls the head down to it.
			var cycle := fmod(_time, SIP_SECONDS) / SIP_SECONDS
			var sip := sin(clampf(cycle / 0.6, 0.0, 1.0) * PI)
			pitch = sip * SIP_DIP
			squash = Vector3(1.0 + sip * 0.03, 1.0 - sip * 0.03, 1.0)
	pitch *= up * motion
	squash = Vector3.ONE.lerp(squash, up * motion)
	# Below the frame when down, and just under the mouth when up.
	var low := Vector3(0.0, -_size * 2.5, 0.0)
	var held := Vector3(0.0, -_size * (0.3 - raise * motion), _size * 0.4)
	position = _mouth + low.lerp(held, up)


func _show_food() -> void:
	_snack.visible = _shown == Need.Action.EAT
	_drink.visible = _shown == Need.Action.DRINK


# A bar, a little tilted, with its lower half in a wrapper.
func _make_snack() -> Node3D:
	var snack := Node3D.new()
	snack.name = "Snack"
	snack.rotation.z = 0.25
	add_child(snack)
	var bar := _box(Vector3(_size * 1.1, _size * 0.45, _size * 0.3), BAR_COLOR)
	snack.add_child(bar)
	var wrapper := _box(Vector3(_size * 0.62, _size * 0.52, _size * 0.36), WRAPPER_COLOR)
	wrapper.position.x = -_size * 0.26
	snack.add_child(wrapper)
	return snack


# A cup with a band round it and a straw up to the mouth.
func _make_drink() -> Node3D:
	var drink := Node3D.new()
	drink.name = "Drink"
	add_child(drink)
	var height := _size * 0.9
	var cup := _cylinder(_size * 0.36, _size * 0.3, height, CUP_COLOR)
	cup.position.y = -height * 0.5
	drink.add_child(cup)
	var band := _cylinder(_size * 0.345, _size * 0.335, height * 0.25, BAND_COLOR)
	band.position.y = -height * 0.45
	drink.add_child(band)
	var straw := _cylinder(_size * 0.05, _size * 0.05, _size * 0.75, STRAW_COLOR)
	straw.rotation.z = -0.35
	straw.position = Vector3(_size * 0.08, _size * 0.2, 0.0)
	drink.add_child(straw)
	return drink


func _box(box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return _part(mesh, color)


func _cylinder(top: float, bottom: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _part(mesh, color)


func _part(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = AlienPortrait.BODY_SHADER
	material.set_shader_parameter(&"light_source", AlienPortrait.LIGHT_DIRECTION)
	material.set_shader_parameter(&"light_is_directional", true)
	material.set_shader_parameter(&"color", color)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	return part
