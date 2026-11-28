class_name WarpGate
extends Node3D
## A warp gate floating beside [member planet]: a hexagonal ring with a glowing core, which
## the bus docked at that planet spends [member fuel_share] of a full tank to go through,
## coming out of [member partner] beside the other planet ([GateService]). It keeps beside
## the planet as it orbits, on the side away from the star, and turns slowly. It builds its
## meshes in code, so the scene saves only its exports.

## The group every gate is in, so a planet's gate can be found from it.
const GROUP := &"warp_gates"
## How far from the planet's centre the gate floats, in units.
const DISTANCE := 1.4
## The ring's size: its radius to the middle of the frame, and the frame's thickness.
const RING_RADIUS := 0.42
const FRAME := 0.07
## How far the ring leans back from upright, so the camera above sees it open.
const LEAN_DEGREES := 50.0
## Seconds per turn of the ring about its own axis.
const TURN_SECONDS := 9.0
const FRAME_COLOR := Color(0.78, 0.8, 0.95)
const CORE_COLOR := Color(0.75, 1.0, 1.0)
const GLOW_COLOR := Color(0.35, 0.85, 1.0, 0.55)
const CORE_RADIUS := 0.11
const GLOW_SIZE := 0.9
## How far past the ring's frame the pointer still counts as on it, in units.
const PICK_SLACK := 0.1

## The planet it floats beside.
@export var planet: Planet
## The gate it leads to.
@export var partner: WarpGate
## What going through costs: this share of a full tank of fuel.
@export_range(0.0, 1.0, 0.05) var fuel_share := 0.5

var _ring: MeshInstance3D


## The gate beside [param at], or null when it has none.
static func of(at: Planet) -> WarpGate:
	if not at or not at.is_inside_tree():
		return null
	for gate: WarpGate in at.get_tree().get_nodes_in_group(GROUP):
		if gate.planet == at:
			return gate
	return null


## The shown gate under [param pointer], seen through [param camera], or null. No physics:
## the ring counts as round on screen, as a planet does ([ScreenPick]).
static func under(camera: Camera3D, pointer: Vector2) -> WarpGate:
	var radius := RING_RADIUS + FRAME + PICK_SLACK
	for gate: WarpGate in camera.get_tree().get_nodes_in_group(GROUP):
		if (
			gate.is_visible_in_tree()
			and ScreenPick.covers(camera, gate.global_position, radius, pointer)
		):
			return gate
	return null


## The planet [param at]'s gate leads to, or null when it has none.
static func twin_of(at: Planet) -> Planet:
	var gate := of(at)
	return gate.partner.planet if gate and gate.partner else null


func _ready() -> void:
	add_to_group(GROUP)
	_build()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not planet:
		return
	var body := planet.get_body_global_position()
	# The planet's star system tells the planet where its star is every frame.
	var star := planet.light_source
	var out := Vector3(body.x - star.x, 0.0, body.z - star.z).normalized()
	global_position = body + out * DISTANCE
	_ring.rotate_object_local(Vector3.UP, TAU * delta / TURN_SECONDS)


## Where the bus comes out of this gate.
func get_exit_point() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func _build() -> void:
	var lean := Node3D.new()
	lean.rotation_degrees.x = LEAN_DEGREES
	add_child(lean, false, Node.INTERNAL_MODE_FRONT)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	# Six steps round makes the ring a hexagon.
	torus.rings = 6
	torus.ring_segments = 6
	torus.inner_radius = RING_RADIUS - FRAME
	torus.outer_radius = RING_RADIUS + FRAME
	torus.material = _flat(FRAME_COLOR)
	_ring.mesh = torus
	lean.add_child(_ring)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = CORE_RADIUS
	sphere.height = CORE_RADIUS * 2.0
	sphere.material = _flat(CORE_COLOR)
	core.mesh = sphere
	add_child(core, false, Node.INTERNAL_MODE_FRONT)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * GLOW_SIZE
	quad.material = _glow()
	glow.mesh = quad
	add_child(glow, false, Node.INTERNAL_MODE_FRONT)


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


# A soft round glow that always faces the camera, adding light to what is behind it.
func _glow() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var material := _flat(GLOW_COLOR)
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material
