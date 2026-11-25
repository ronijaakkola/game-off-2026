class_name Capsule
extends Node3D
## A capsule adrift in space, which the bus collects by flying into it ([CapsuleField]). It
## drifts in a straight line and tumbles slowly, every one alike, whatever it turns out to
## hold: a white band round its middle and a white glow behind it that blinks, as a beacon.
## It emerges as it appears and shrinks away over its last seconds. It builds its meshes in
## code.

## What it holds: [constant UNDECIDED] until the bus collects it and the [CapsuleField]
## rolls, or what the debug panel put in it.
enum Contents { CREDITS = 0, RESEARCH = 1, PASSENGER = 2, UNDECIDED = 3 }

## Its size: the radius of its round ends, and its length end to end.
const RADIUS := 0.12
const LENGTH := 0.44
const BAND_WIDTH := 0.09
const BODY_COLOR := Color(0.86, 0.85, 0.95)
## The band's and the glow's colour.
const BEACON_COLOR := Color(1.0, 1.0, 1.0)
const GLOW_SIZE := 0.85
const GLOW_ALPHA := 0.55
## Seconds from one blink of its beacon to the next, and how dim it gets between.
const BLINK_SECONDS := 1.2
const BLINK_LOW := 0.15
## Radians a second it tumbles about its own axis.
const TUMBLE_SPEED := 0.25
## Seconds it takes to emerge as it appears, from nothing to its size with a springy
## overshoot, and to shrink away at the end of its time.
const APPEAR_SECONDS := 1.1
const VANISH_SECONDS := 2.0
const TWO_TONE := preload("res://shared/two_tone.gdshader")

## What it holds.
var contents := Contents.UNDECIDED
## Where it drifts, in units a second.
var velocity := Vector3.ZERO
## Seconds until it is gone uncollected.
var seconds_left := 90.0
## Where its light comes from: the star of its system.
var light_source := Vector3.ZERO:
	set(value):
		light_source = value
		if _body_material:
			ShaderValues.show(_body_material, &"light_source", value)

var _age := 0.0
var _tumble_axis := Vector3.UP
var _body: Node3D
var _body_material: ShaderMaterial
var _glow_material: StandardMaterial3D


func _ready() -> void:
	_build()
	scale = Vector3.ONE * 0.001


func _process(delta: float) -> void:
	_age += delta
	seconds_left -= delta
	position += velocity * delta
	_body.rotate(_tumble_axis, TUMBLE_SPEED * delta)
	var left := clampf(seconds_left / VANISH_SECONDS, 0.0, 1.0)
	scale = Vector3.ONE * maxf(_get_emerged() * ease(left, 0.4), 0.001)
	var beat := fposmod(_age, BLINK_SECONDS) / BLINK_SECONDS
	var light := lerpf(1.0, BLINK_LOW, smoothstep(0.0, 0.5, beat))
	_glow_material.albedo_color.a = GLOW_ALPHA * light


## How far it has emerged, as a share of its size: from 0 as it appears, swelling past 1 and
## settling back to it over [constant APPEAR_SECONDS]. Under Reduce motion it eases in
## without the overshoot.
func _get_emerged() -> float:
	if _age >= APPEAR_SECONDS:
		return 1.0
	var trans := Tween.TRANS_SINE if Settings.reduce_motion else Tween.TRANS_BACK
	return Tween.interpolate_value(0.0, 1.0, _age, APPEAR_SECONDS, trans, Tween.EASE_OUT)


## Whether its time is up.
func is_gone() -> bool:
	return seconds_left <= 0.0


## Where it is, on the orbit plane.
func get_flat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


## Sets it tumbling about an axis of [param rng]'s choosing, so no two turn alike.
func pick_tumble(rng: RandomNumberGenerator) -> void:
	var axis := Vector3(rng.randf_range(-1.0, 1.0), 1.0, rng.randf_range(-1.0, 1.0))
	_tumble_axis = axis.normalized()


func _build() -> void:
	var color := BEACON_COLOR
	_body = Node3D.new()
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var shell := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = RADIUS
	capsule.height = LENGTH
	_body_material = ShaderMaterial.new()
	_body_material.shader = TWO_TONE
	_body_material.set_shader_parameter(&"color", BODY_COLOR)
	_body_material.set_shader_parameter(&"light_source", light_source)
	capsule.material = _body_material
	shell.mesh = capsule
	# Lying on its side, so the camera above sees it long.
	shell.rotation_degrees.z = 90.0
	_body.add_child(shell)
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = RADIUS * 1.08
	ring.bottom_radius = RADIUS * 1.08
	ring.height = BAND_WIDTH
	ring.material = _flat(color)
	band.mesh = ring
	band.rotation_degrees.z = 90.0
	_body.add_child(band)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * GLOW_SIZE
	_glow_material = _glow(color)
	quad.material = _glow_material
	glow.mesh = quad
	add_child(glow, false, Node.INTERNAL_MODE_FRONT)


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


# A soft round glow that always faces the camera, adding light to what is behind it.
func _glow(color: Color) -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var material := _flat(Color(color, GLOW_ALPHA))
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material
