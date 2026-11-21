class_name CameraWatch
extends RefCounted
## Whether the player has tried both ways of moving the camera since it started watching:
## panned it [constant PAN] units in all, about a quarter of a second of panning, and zoomed
## it by [constant ZOOM] of its distance, one wheel notch. A pointer passing the window's
## edge doesn't pan it that far. [method is_tried] adds up the way panned, so it is called
## every frame.

## How far the look-at point must have travelled, in the rig's parent's space.
const PAN := 8.0
## How much of its distance the zoom must have changed by.
const ZOOM := 0.1

var _rig: CameraRig
var _last_position: Vector3
var _panned := 0.0
var _from_distance: float
var _zoomed := false


func _init(rig: CameraRig) -> void:
	_rig = rig
	_last_position = rig.position
	_from_distance = rig.distance


func is_tried() -> bool:
	_panned += _rig.position.distance_to(_last_position)
	_last_position = _rig.position
	_zoomed = _zoomed or absf(_rig.distance / _from_distance - 1.0) >= ZOOM
	return _panned >= PAN and _zoomed
