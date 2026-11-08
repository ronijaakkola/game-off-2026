class_name BusModel
extends Node3D
## The bus's model: `models/bus.glb` under it, redrawn with the planets' two-tone light in
## the colours it was made with. Its thrusters' exhaust glows and grows by [member thrust].
## It can show a white border round it, as a planet under the pointer does.

const SHADER := preload("res://shared/two_tone.gdshader")
const OUTLINE_SHADER := preload("res://game/bus/bus_outline.gdshader")
## The border's colour, the white of a hovered planet's.
const BORDER_COLOR := Color.WHITE
# The glb's node for the thrusters' exhaust, lit by thrust rather than by the star. Its
# origin is at the nozzles.
const GLOW_NODE := &"ThrusterGlow"
# How long the exhaust is with the drive off, as a share of its full length.
const OFF_LENGTH := 0.1

## The thrusters' colour at full thrust.
@export var thruster_color := Color(0.6, 0.95, 1.0)
## The thrusters' colour with the drive off.
@export var thruster_off_color := Color(0.18, 0.17, 0.32)

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
