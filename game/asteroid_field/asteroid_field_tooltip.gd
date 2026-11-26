class_name AsteroidFieldTooltip
extends WorldTooltip
## Names the asteroid field under the pointer, as a [WorldTooltip]. The whole of
## [member field]'s band counts, its gaps and the room between its rocks too, and a little
## past its edges, so the pointer needn't hit a rock. No physics: it asks the belt about
## the spot on the orbit plane the pointer looks at.

const TEXT := "Asteroid field"
## How far past the band's edges the pointer still counts as over it, in units.
const SLACK := 0.4

## The field it names.
@export var field: AsteroidField


func _get_text() -> String:
	return TEXT


func _is_over(camera: Camera3D, pointer: Vector2) -> bool:
	if not field or not field.is_visible_in_tree():
		return false
	var point: Variant = CourseDrag.point_under(camera, pointer)
	if point == null:
		return false
	return field.belt.is_in_band(field.to_local(point as Vector3), -SLACK)
