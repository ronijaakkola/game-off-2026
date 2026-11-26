class_name CapsuleTooltip
extends WorldTooltip
## Names the capsule under the pointer, as a [WorldTooltip], while it drifts and shows: not
## once the bus has it. No physics: the pod counts as round on screen ([ScreenPick]).

const TEXT := "Drifting capsule"


func _get_text() -> String:
	return TEXT


func _is_over(camera: Camera3D, pointer: Vector2) -> bool:
	for capsule: Capsule in get_tree().get_nodes_in_group(Capsule.GROUP):
		if not capsule.is_adrift() or not capsule.is_visible_in_tree():
			continue
		var radius := Capsule.PICK_RADIUS * capsule.scale.x
		if ScreenPick.covers(camera, capsule.global_position, radius, pointer):
			return true
	return false
