class_name MapCursor
## Which pointer the map asks the [code]Cursor[/code] for, once a frame. The later of
## these wins: adding a stop with the [QueueKey] held, a map that takes no clicks, panning
## at a window edge, steering a point in space by hand, and dragging the camera. With the
## queue key held, steering keeps the pointer for adding a stop, which shows the press.


## Asks for the pointer that fits what the player is doing. [param steering] is whether a
## point in space follows the pointer, [param over_hud] whether the pointer is over a
## Control, and [param locked] whether the map takes no clicks.
static func show(rig: CameraRig, steering: bool, over_hud: bool, locked: bool) -> void:
	var edge := Vector2i(rig.get_edge_pan())
	var shape := Cursor.Shape.DEFAULT
	if rig.is_dragging():
		shape = Cursor.Shape.DRAG
	elif steering and not QueueKey.is_held():
		shape = Cursor.Shape.STEER
	elif edge != Vector2i.ZERO:
		shape = Cursor.Shape.EDGE_PAN
	elif locked and not over_hud:
		shape = Cursor.Shape.LOCKED
	elif QueueKey.is_held() and not over_hud:
		shape = Cursor.Shape.ADD_STOP
	Cursor.show_shape(shape, edge)
