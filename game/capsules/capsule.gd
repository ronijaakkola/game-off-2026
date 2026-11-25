class_name Capsule
extends Node3D
## A capsule adrift in space, which the bus collects by flying into it ([CapsuleField]). It
## is an escape pod (`models/capsule.glb`): a pale pill with two trim rings, tail fins, a
## porthole and a lamp on its nose. It drifts in a straight line and tumbles slowly, every
## one alike, whatever it turns out to hold. Its lamp blinks as a beacon, and with each
## blink a thin ring spreads from it on the orbit plane and fades. It emerges as it appears
## and shrinks away over its last seconds, or quickly once the bus picks it up
## ([method pick_up]). The one the castaway was in stays a moment first, its lamp lit, as
## they come out of it ([method release]).

## What it holds: [constant UNDECIDED] until the bus collects it and the [CapsuleField]
## rolls, or what the debug panel put in it.
enum Contents { CREDITS = 0, RESEARCH = 1, PASSENGER = 2, UNDECIDED = 3, FUEL = 4 }

## How near its centre the bus collects it.
const RADIUS := 0.12
## How near its centre on screen the pointer is on it, as round as its longest side.
const PICK_RADIUS := 0.2
## Every capsule in the tree, for what looks for one under the pointer.
const GROUP := &"capsules"
## How high its model's centre is over the model's origin, which is at its bottom.
const MODEL_CENTER := 0.17
## The model's node that is the beacon's lamp, and the lamp's colour lit and between blinks.
const LAMP_NODE := "CapsuleLamp"
const LAMP_COLOR := Color(1.0, 1.0, 1.0)
const LAMP_DIM_COLOR := Color(0.45, 0.4, 0.75)
## Seconds from one blink of its beacon to the next, and how long the lamp stays lit.
const BLINK_SECONDS := 1.6
const LAMP_SECONDS := 0.35
## The ring a blink sends out: how far it spreads, how thick its line is, how long it takes
## and how solid it starts.
const PING_RADIUS := 0.6
const PING_START := 0.3
const PING_WIDTH := 0.012
const PING_SECONDS := 1.1
const PING_ALPHA := 0.7
## Radians a second it tumbles about its own axis.
const TUMBLE_SPEED := 0.25
## Seconds it takes to grow to its size as it appears, and to shrink away at the end of
## its time.
const APPEAR_SECONDS := 0.25
const VANISH_SECONDS := 2.0
## Seconds it takes to shrink to nothing once the bus picks it up.
const PICKUP_SECONDS := 0.18
## How much it swells as the castaway comes out of it, as a share of its size, and the
## seconds the swell takes.
const RELEASE_SWELL := 0.3
const RELEASE_SECONDS := 0.3
const MODEL := preload("res://game/capsules/models/capsule.glb")
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
		for material: ShaderMaterial in _materials:
			ShaderValues.show(material, &"light_source", value)

var _age := 0.0
# Seconds since the bus picked it up, or -1 while it is adrift.
var _picked_for := -1.0
# Seconds since the castaway started coming out of it, or -1, and how long it stays for
# that.
var _released_for := -1.0
var _open_seconds := 0.0
var _tumble_axis := Vector3.UP
var _body: Node3D
var _materials: Array[ShaderMaterial] = []
var _lamp_material: StandardMaterial3D
var _ping: Node3D
var _ping_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	scale = Vector3.ONE * 0.001


func _process(delta: float) -> void:
	_age += delta
	seconds_left -= delta
	position += velocity * delta
	_body.rotate(_tumble_axis, TUMBLE_SPEED * delta)
	var left := clampf(seconds_left / VANISH_SECONDS, 0.0, 1.0)
	var picked := 1.0
	if _picked_for >= 0.0:
		_picked_for += delta
		if _picked_for >= PICKUP_SECONDS:
			queue_free()
			return
		# Fast at first, so it reads as taken at once.
		picked = 1.0 - ease(_picked_for / PICKUP_SECONDS, 0.4)
	var swell := 1.0
	if _released_for >= 0.0 and _picked_for < 0.0:
		_released_for += delta
		if _released_for >= _open_seconds:
			pick_up()
		elif not Settings.reduce_motion:
			var popped := clampf(_released_for / RELEASE_SECONDS, 0.0, 1.0)
			swell += RELEASE_SWELL * sin(PI * popped)
	scale = Vector3.ONE * maxf(_get_emerged() * ease(left, 0.4) * picked * swell, 0.001)
	var beat := fposmod(_age, BLINK_SECONDS)
	var lit := 1.0 if _released_for >= 0.0 else 1.0 - smoothstep(0.0, LAMP_SECONDS, beat)
	_lamp_material.albedo_color = LAMP_DIM_COLOR.lerp(LAMP_COLOR, lit)
	var spread := ease(clampf(beat / PING_SECONDS, 0.0, 1.0), 0.35)
	# Under Reduce motion the ring fades where it is.
	var size := 1.0 if Settings.reduce_motion else lerpf(PING_START, 1.0, spread)
	_ping.scale = Vector3(size, 1.0, size)
	_ping_material.albedo_color.a = PING_ALPHA * (1.0 - spread)


## How far it has emerged, as a share of its size: from 0 as it appears to 1 over
## [constant APPEAR_SECONDS], fast at first, as it shrinks when picked up. Under Reduce
## motion it is there at once.
func _get_emerged() -> float:
	if _age >= APPEAR_SECONDS or Settings.reduce_motion:
		return 1.0
	return ease(_age / APPEAR_SECONDS, 0.4)


## The bus picked it up: it shrinks to nothing over [constant PICKUP_SECONDS] and frees
## itself, without another ring. Under Reduce motion it is gone at once.
func pick_up() -> void:
	if Settings.reduce_motion:
		queue_free()
		return
	_picked_for = 0.0
	_ping.visible = false


## The castaway comes out of it: it sends no more rings, swells once and stays
## [param seconds] with its lamp lit, then goes as one picked up does. Under Reduce motion
## it doesn't swell.
func release(seconds: float) -> void:
	_released_for = 0.0
	_open_seconds = seconds
	_ping.visible = false


## Whether it still drifts: neither picked up by the bus nor letting the castaway out.
func is_adrift() -> bool:
	return _picked_for < 0.0 and _released_for < 0.0


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
	_body = Node3D.new()
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var model := MODEL.instantiate() as Node3D
	model.position.y = -MODEL_CENTER
	# Lying across the view, so the camera above sees it long.
	model.rotation_degrees.y = 90.0
	_body.add_child(model)
	_lamp_material = _flat(LAMP_COLOR)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.name == LAMP_NODE:
			part.material_override = _lamp_material
			continue
		for surface: int in part.mesh.get_surface_count():
			var imported := part.mesh.surface_get_material(surface) as BaseMaterial3D
			var material := ShaderMaterial.new()
			material.shader = TWO_TONE
			material.set_shader_parameter(&"color", imported.albedo_color)
			material.set_shader_parameter(&"light_source", light_source)
			_materials.append(material)
			part.set_surface_override_material(surface, material)
	# The ring lies on the orbit plane and doesn't tumble.
	var ring := TorusMesh.new()
	ring.inner_radius = PING_RADIUS - PING_WIDTH
	ring.outer_radius = PING_RADIUS + PING_WIDTH
	ring.rings = 48
	ring.ring_segments = 4
	_ping_material = _flat(Color(LAMP_COLOR, PING_ALPHA))
	_ping_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = _ping_material
	var ping := MeshInstance3D.new()
	ping.mesh = ring
	ping.scale.y = 0.01
	_ping = Node3D.new()
	_ping.add_child(ping)
	add_child(_ping, false, Node.INTERNAL_MODE_FRONT)


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
