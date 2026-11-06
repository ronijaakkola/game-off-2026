@tool
extends Node3D
## The bus's placeholder model, built in code: a rounded body, a dark window band that wraps
## round both ends, and a glowing thruster at the back. It faces +Z, centred on its origin.
## It builds its meshes as internal nodes, so the scene saves only its exports.

const SHADER := preload("res://game/bus/bus.gdshader")

@export var body_size := Vector3(0.36, 0.32, 0.78):
	set(value):
		body_size = value
		_rebuild()
@export var body_color := Color(1.0, 0.78, 0.3):
	set(value):
		body_color = value
		_rebuild()
@export var window_color := Color(0.3, 0.27, 0.55):
	set(value):
		window_color = value
		_rebuild()
@export var thruster_color := Color(0.6, 0.95, 1.0):
	set(value):
		thruster_color = value
		_rebuild()

var _body := MeshInstance3D.new()
var _windows := MeshInstance3D.new()
var _thruster := MeshInstance3D.new()


func _init() -> void:
	for part: MeshInstance3D in [_body, _windows, _thruster]:
		add_child(part, false, INTERNAL_MODE_FRONT)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var radius := body_size.y * 0.3
	_body.mesh = RoundedBox.make(body_size, radius)
	_body.material_override = _flat(body_color)
	# A band a little wider and longer than the body, so it shows on the sides and at both
	# ends: the windscreen at the front, the rear window at the back.
	var band := Vector3(body_size.x + 0.02, body_size.y * 0.42, body_size.z + 0.02)
	_windows.mesh = RoundedBox.make(band, band.y * 0.45)
	_windows.position.y = body_size.y * 0.1
	_windows.material_override = _flat(window_color)
	var nozzle := Vector3(body_size.x * 0.55, body_size.y * 0.4, 0.1)
	_thruster.mesh = RoundedBox.make(nozzle, nozzle.y * 0.4)
	_thruster.position = Vector3(0.0, -body_size.y * 0.1, -body_size.z * 0.5)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = thruster_color
	_thruster.material_override = glow


func _flat(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"color", color)
	return material
