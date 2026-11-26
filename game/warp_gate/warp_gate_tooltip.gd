class_name WarpGateTooltip
extends WorldTooltip
## Names the warp gate under the pointer, as a [WorldTooltip]. No physics: the ring counts
## as round on screen, as a planet does ([ScreenPick]).

const TEXT := "Warp drive"
## How far past the ring's frame the pointer still counts as on it, in units.
const SLACK := 0.1


func _get_text() -> String:
	return TEXT


func _is_over(camera: Camera3D, pointer: Vector2) -> bool:
	var radius := WarpGate.RING_RADIUS + WarpGate.FRAME + SLACK
	for gate: WarpGate in get_tree().get_nodes_in_group(WarpGate.GROUP):
		if (
			gate.is_visible_in_tree()
			and ScreenPick.covers(camera, gate.global_position, radius, pointer)
		):
			return true
	return false
