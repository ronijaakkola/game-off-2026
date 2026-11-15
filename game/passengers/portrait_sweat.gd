class_name PortraitSweat
extends Node3D
## Sweat on a portrait's head while the bus is too hot: cartoon drops that well up on the
## head's left side and brow as the camera sees it, clear of the anger mark, slide down a
## little and shrink away, one after another. More of them as [method advance] is given
## more sweat. It sits on the head, so the drops lean, nod and tremble with it, over any
## face: angry, happy, asleep, eating or watching. Under Reduce motion they sit still.

const SHADER := preload("res://game/passengers/sweat_drop.gdshader")
## A drop's width, as a share of the head's size (the mean of its width and height); it is
## [constant HEIGHT_SHARE] times as tall.
const SIZE := 0.26
const HEIGHT_SHARE := 1.4
## Where each drop wells up, from the head's middle, as a share of its size. One that would
## hang off the head's own shape, such as under the Hammer's bar, moves up onto it. The
## sweat from which each drop shows: the first from any sweat at all.
const SPOTS: Array[Vector2] = [Vector2(-0.4, 0.22), Vector2(-0.12, 0.4), Vector2(0.38, 0.05)]
const SHOWS_FROM: Array[float] = [0.0, 0.3, 0.65]
## Seconds a drop takes from welling up to gone, how far it slides down meanwhile, as a
## share of the head's height, and the shares of that time it grows in and shrinks away.
const DROP_SECONDS := 1.6
const SLIDE := 0.3
const GROW := 0.15
const SHRINK := 0.25
## Under Reduce motion, how far through its slide a drop sits still.
const STILL_AT := 0.3

var _drops: Array[MeshInstance3D] = []
var _rest: Array[Vector3] = []
var _slide := 0.0
var _time := 0.0


## Makes the drops on the head this node sits on, whose own shape is [param meshes].
func setup(meshes: Array[MeshInstance3D]) -> void:
	var points := _points(meshes)
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		bounds = bounds.expand(point)
	var size := (bounds.size.x + bounds.size.y) * 0.5
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, HEIGHT_SHARE) * size * SIZE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 1
	material.set_shader_parameter(&"height_share", HEIGHT_SHARE)
	_slide = bounds.size.y * SLIDE
	var middle := bounds.get_center()
	for spot: Vector2 in SPOTS:
		var drop := MeshInstance3D.new()
		drop.mesh = quad
		drop.material_override = material
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drop.visible = false
		var x := middle.x + bounds.size.x * spot.x
		var y := middle.y + bounds.size.y * spot.y
		var span := _span_at(points, x, bounds.size.x * 0.08, middle.z, bounds.size.y * 0.1)
		if span != Vector2.ZERO:
			y = clampf(y, minf(span.x + quad.size.y * 0.5, span.y), span.y)
		_rest.append(Vector3(x, y, bounds.end.z))
		add_child(drop)
		_drops.append(drop)


## Runs [param delta] seconds with them sweating [param sweat], from 0 not at all to 1 as
## hard as they can, moving by [param motion].
func advance(delta: float, sweat: float, motion: float) -> void:
	_time = _time + delta if sweat > 0.0 else 0.0
	for i: int in _drops.size():
		var drop := _drops[i]
		drop.visible = sweat > SHOWS_FROM[i] and sweat > 0.0
		if not drop.visible:
			continue
		# Each drop runs its own way through the loop, so they don't move together.
		var t := fposmod(_time / DROP_SECONDS + i * 0.37, 1.0)
		t = lerpf(STILL_AT, t, motion)
		var grow := minf(t / GROW, 1.0) * minf((1.0 - t) / SHRINK, 1.0)
		drop.scale = Vector3.ONE * maxf(ease(grow, 0.5), 0.001)
		drop.position = _rest[i] + Vector3.DOWN * _slide * ease(t, 1.8)


# Every corner of [param meshes]' faces, in the head's space.
func _points(meshes: Array[MeshInstance3D]) -> PackedVector3Array:
	var to_head := get_parent_node_3d().global_transform.affine_inverse()
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in meshes:
		var to_local := to_head * mesh.global_transform
		for point: Vector3 in mesh.mesh.get_faces():
			points.append(to_local * point)
	return points


# The bottom and top of the part of [param points] in front of [param front] and within
# [param band] of [param x] that reaches down from the top without a gap of [param gap], so
# a neck that flares out below doesn't count. Zero when none are there.
func _span_at(
	points: PackedVector3Array, x: float, band: float, front: float, gap: float
) -> Vector2:
	var heights: Array[float] = []
	for point: Vector3 in points:
		if absf(point.x - x) <= band and point.z >= front:
			heights.append(point.y)
	if heights.is_empty():
		return Vector2.ZERO
	heights.sort()
	heights.reverse()
	var bottom := heights[0]
	for height: float in heights:
		if bottom - height > gap:
			break
		bottom = height
	return Vector2(bottom, heights[0])
