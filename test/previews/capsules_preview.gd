extends Node
## The game started docked at Ember with three capsules adrift just off it, alike to look
## at but set to hold credits, research points and the castaway, the camera close, to look
## at them (F6) or capture them. With `fly` after `--`, the bus flies into the credits
## capsule, stamping what it held over the bus: `-- fly`. With `rescue`, it flies into the
## castaway's capsule instead, and they call.

## How far the camera stands from the bus.
const NEAR_DISTANCE := 10.0
## Where each capsule floats, from the bus.
const OFFSETS: Dictionary[Capsule.Contents, Vector3] = {
	Capsule.Contents.CREDITS: Vector3(1.0, 0.0, 2.0),
	Capsule.Contents.RESEARCH: Vector3(0.5, 0.0, -2.5),
	Capsule.Contents.PASSENGER: Vector3(-2.0, 0.0, -1.5),
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	await get_tree().process_frame
	var bus := find_child("Bus") as FrameshiftBus
	var field := find_child("CapsuleField") as CapsuleField
	field.enabled = false
	var rig := find_child("CameraRig") as CameraRig
	rig.set_distance(NEAR_DISTANCE)
	rig.move_to(bus.global_position)
	var targets: Dictionary[Capsule.Contents, Vector3] = {}
	for contents: Capsule.Contents in OFFSETS:
		var capsule := field.spawn(bus.global_position + OFFSETS[contents], contents)
		capsule.velocity = Vector3.ZERO
		targets[contents] = capsule.global_position
	var target := Vector3.ZERO
	if "fly" in args:
		target = targets[Capsule.Contents.CREDITS]
	elif "rescue" in args:
		target = targets[Capsule.Contents.PASSENGER]
	else:
		return
	bus.plot_course(RouteStop.at_point(target))
	bus.frameshift_held = true
