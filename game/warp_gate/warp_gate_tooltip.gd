class_name WarpGateTooltip
extends WorldTooltip
## Names the warp gate under the pointer, as a [WorldTooltip]. The gate beside the planet
## the bus is docked at reads what a click on it does, as the dock panel's warp button does
## ([GateService]).

const TEXT := "Warp drive"

## Says what a click on the gate does. Without it, every gate reads [constant TEXT].
@export var gate_service: GateService

# The gate under the pointer, as of the last _is_over().
var _over: WarpGate


func _get_text() -> String:
	var offer := gate_service.get_offer(_over) if gate_service and _over else ""
	return offer if not offer.is_empty() else TEXT


func _is_over(camera: Camera3D, pointer: Vector2) -> bool:
	_over = WarpGate.under(camera, pointer)
	return _over != null
