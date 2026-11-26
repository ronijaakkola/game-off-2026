extends Node
## The game with the camera moved off the bus, so the off-screen bus indicator shows, to
## capture it. After `--`, `left`, `right`, `up` and `down` say which way the bus is from
## the screen, and two make a corner: `capture <this scene> -- up left`; with none it is
## off to the left. With `under` it is on screen but under the station panel. With `fuel`
## the tank is empty, and with `far` the camera stands farther back.

## How far the camera stands from the map.
const DISTANCE := 12.0
const FAR_DISTANCE := 24.0
## How far the camera moves off the bus for each way named, in units.
const OFFSETS: Dictionary[String, Vector3] = {
	"left": Vector3(14.0, 0.0, 0.0),
	"right": Vector3(-14.0, 0.0, 0.0),
	"up": Vector3(0.0, 0.0, 10.0),
	"down": Vector3(0.0, 0.0, -10.0),
	"under": Vector3(-10.5, 0.0, 3.5),
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	await get_tree().process_frame
	var bus := find_child("Bus") as FrameshiftBus
	var rig := find_child("CameraRig") as CameraRig
	var offset := Vector3.ZERO
	for arg: String in args:
		offset += OFFSETS.get(arg, Vector3.ZERO) as Vector3
	if offset == Vector3.ZERO:
		offset = OFFSETS["left"]
	if "fuel" in args:
		bus.get_fuel_tank().drain()
	rig.set_distance(FAR_DISTANCE if "far" in args else DISTANCE)
	rig.move_to(bus.global_position + offset)
