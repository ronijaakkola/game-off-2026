class_name AngerMark
extends MeshInstance3D
## A portrait's red cartoon anger mark: a quad facing the camera on the head's upper right
## as the camera sees it, on the head so it trembles and leans with it. It goes by the
## head's own mesh, not the stalks or eyes on it, so it sits clear of them. Hidden until
## [method show_fury] gives it some fury; then it grows in and pulses.

const SHADER := preload("res://game/passengers/anger_mark.gdshader")
## Its size, as a share of the head's (the mean of its width and height), and where it sits
## on the head's upper right, from its middle, as a share of the head's size.
const SIZE := 0.42
const AT := Vector2(0.3, 0.5)
## How fast it pulses, and by how much of its size.
const PULSE_SPEED := 7.0
const PULSE := 0.12


## Puts it on [param head] for a head whose own mesh has [param bounds] in
## [param portrait]'s space.
func setup(portrait: Node3D, head: Node3D, bounds: AABB) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (bounds.size.x + bounds.size.y) * 0.5 * SIZE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 1
	mesh = quad
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	var middle := bounds.get_center()
	var offset := Vector2(bounds.size.x, bounds.size.y) * AT
	var at := Vector3(middle.x + offset.x, middle.y + offset.y, bounds.end.z)
	head.add_child(self)
	global_position = portrait.global_transform * at
	global_basis = portrait.global_basis


## Shows [param fury], from 0 to 1, [param time] seconds in, pulsing by [param motion].
func show_fury(fury: float, time: float, motion: float) -> void:
	var pulse := 1.0 + sin(time * PULSE_SPEED) * PULSE * motion
	var grow := ease(fury, 0.4)
	scale = Vector3.ONE * maxf(grow * pulse, 0.001)
	visible = grow > 0.0
