class_name WarpGateTooltip
extends WorldTooltip
## Names the warp gate under the pointer, as a [WorldTooltip]. The gate beside the planet
## the bus is docked at reads what a click on it does ([GateService]): where it goes, and
## under that what it costs, in red while the tank holds too little.

const TEXT := "Warp drive"

## Says what a click on the gate does. Without it, every gate reads [constant TEXT].
@export var gate_service: GateService

# The gate under the pointer, as of the last _is_over().
var _over: WarpGate


func _get_title() -> String:
	return gate_service.get_route(_over) if gate_service and _over else ""


func _get_text() -> String:
	var cost := gate_service.get_cost(_over) if gate_service and _over else ""
	return cost if not cost.is_empty() else TEXT


func _is_warning() -> bool:
	return gate_service != null and gate_service.is_short(_over)


func _is_over(camera: Camera3D, pointer: Vector2) -> bool:
	_over = WarpGate.under(camera, pointer)
	return _over != null
