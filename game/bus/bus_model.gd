class_name BusModel
extends Node3D
## The bus's model: `models/bus.glb` under it, redrawn with the planets' two-tone light in
## the colours it was made with. Its thrusters' exhaust glows and grows by [member thrust].

const SHADER := preload("res://shared/two_tone.gdshader")
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

var _glow := StandardMaterial3D.new()
var _exhaust: MeshInstance3D


func _ready() -> void:
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.name == GLOW_NODE:
			part.material_override = _glow
			_exhaust = part
			continue
		for surface: int in part.mesh.get_surface_count():
			var imported := part.mesh.surface_get_material(surface) as BaseMaterial3D
			part.set_surface_override_material(surface, _flat(imported.albedo_color))
	thrust = thrust


func _flat(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"color", color)
	return material
