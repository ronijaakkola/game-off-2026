class_name BusModel
extends Node3D
## The bus's model: `models/bus.glb` under it, redrawn with the planets' two-tone light in
## the colours it was made with. Its thrusters' exhaust glows and grows by [member thrust].
## It can show a white border round it, as a planet under the pointer does. The bus moves
## it with [method animate]: a float while still, a shake while the drive charges and a
## lean into turns.

const SHADER := preload("res://shared/two_tone.gdshader")
const OUTLINE_SHADER := preload("res://game/bus/bus_outline.gdshader")
## The border's colour, the white of a hovered planet's.
const BORDER_COLOR := Color.WHITE
# The glb's node for the thrusters' exhaust, lit by thrust rather than by the star. Its
# origin is at the nozzles.
const GLOW_NODE := &"ThrusterGlow"
# How long the exhaust is with the drive off, as a share of its full length.
const OFF_LENGTH := 0.1
# How far the model leans per radian per second of turn.
const BANK := 0.12

## The thrusters' colour at full thrust.
@export var thruster_color := Color(0.6, 0.95, 1.0)
## The thrusters' colour with the drive off.
@export var thruster_off_color := Color(0.18, 0.17, 0.32)

@export_group("Float")
## How far the bus bobs up and down while still.
@export_range(0.0, 1.0, 0.01) var bob_height := 0.02
@export_range(0.1, 20.0, 0.1) var bob_period := 2.6
## How far the bus sways side to side while still.
@export_range(0.0, 1.0, 0.01) var sway := 0.01
@export_range(0.1, 20.0, 0.1) var sway_period := 4.3
## How far the bus shakes when the drive is fully charged. Reduce motion turns it off.
@export_range(0.0, 0.5, 0.005) var charge_shake := 0.012
@export_group("")

## How brightly the thrusters glow, from 0 (off) to 1.
var thrust := 0.0:
	set(value):
		thrust = clampf(value, 0.0, 1.0)
		_glow.albedo_color = thruster_off_color.lerp(thruster_color, thrust)
		if _exhaust:
			_exhaust.scale.z = lerpf(OFF_LENGTH, 1.0, thrust)

## Whether the white border round the bus shows.
var border := false:
	set(value):
		border = value
		_show_border()
## How far the border reaches past the bus's edge.
var outline_width := 0.02:
	set(value):
		outline_width = value
		for outline: ShaderMaterial in _outlines:
			outline.set_shader_parameter(&"width", value)

var _glow := StandardMaterial3D.new()
var _exhaust: MeshInstance3D
# Each part's border, drawn after it. Always there, see-through while off, so the first
# hover doesn't compile a shader mid-game.
var _outlines: Array[ShaderMaterial] = []
var _time := 0.0
# How much of the float shows: 1 while still, 0 in flight.
var _float := 1.0


func _ready() -> void:
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Marks the stencil as two_tone.gdshader does, so the border stays off the nozzles.
	_glow.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	_glow.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	_glow.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	_glow.stencil_reference = 1
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.name == GLOW_NODE:
			part.material_override = _glow
			_exhaust = part
			continue
		var outline := _make_outline(part.mesh.get_aabb())
		_outlines.append(outline)
		for surface: int in part.mesh.get_surface_count():
			var imported := part.mesh.surface_get_material(surface) as BaseMaterial3D
			var flat := _flat(imported.albedo_color)
			flat.next_pass = outline
			part.set_surface_override_material(surface, flat)
	thrust = thrust
	border = border
	outline_width = outline_width


## Moves the model for a frame: it floats while [param still], shakes by how far the drive
## has [param charged] (0 to 1), and leans into a turn of [param turn_rate] radians per
## second.
func animate(delta: float, still: bool, charged: float, turn_rate: float) -> void:
	_time += delta
	_float = move_toward(_float, 1.0 if still else 0.0, delta)
	var offset := Vector3(
		sin(TAU * _time / sway_period) * sway, sin(TAU * _time / bob_period) * bob_height, 0.0
	)
	position = offset * _float
	if charged > 0.0 and not Settings.reduce_motion:
		var shake := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0)
		position += shake * charge_shake * charged
	var lean := clampf(-turn_rate * BANK, -0.5, 0.5)
	rotation.z = lerp_angle(rotation.z, lean, 1.0 - exp(-8.0 * delta))


func _flat(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"color", color)
	return material


func _make_outline(box: AABB) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter(&"box_center", box.get_center())
	material.set_shader_parameter(&"box_half_size", box.size * 0.5)
	return material


func _show_border() -> void:
	var color := BORDER_COLOR
	color.a = 1.0 if border else 0.0
	for outline: ShaderMaterial in _outlines:
		outline.set_shader_parameter(&"color", color)
