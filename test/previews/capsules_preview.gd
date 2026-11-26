extends Node
## The game started docked at Ember with three capsules adrift just off it, alike to look
## at but set to hold credits, research points and the castaway, the camera close, to look
## at them (F6) or capture them. With `fly` after `--`, the bus flies into the credits
## capsule, stamping what it held over the bus: `-- fly`. With `rescue`, it flies into the
## castaway's capsule instead, and they call. With `open`, the castaway's capsule is on the bus
## from the start, so they come out of it at once; with `accept` or `decline` too, the
## transmission they open is answered that way 1.75 s in. With `hover`, the pointer rests on
## the credits capsule, so its tooltip shows.

## How far the camera stands from the bus.
const NEAR_DISTANCE := 10.0
## Seconds in that `accept` or `decline` answers the castaway's transmission.
const ANSWER_SECONDS := 1.75
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
	if "open" in args:
		field.spawn(bus.global_position, Capsule.Contents.PASSENGER)
		if "accept" in args or "decline" in args:
			await get_tree().create_timer(ANSWER_SECONDS).timeout
			var panel := find_child("TransmissionPanel") as TransmissionPanel
			if "accept" in args:
				panel.accept()
			else:
				panel.close()
		return
	if "hover" in args:
		_hover(targets[Capsule.Contents.CREDITS])
		return
	var target := Vector3.ZERO
	if "fly" in args:
		target = targets[Capsule.Contents.CREDITS]
	elif "rescue" in args:
		target = targets[Capsule.Contents.PASSENGER]
	else:
		return
	bus.plot_course(RouteStop.at_point(target))
	bus.frameshift_held = true


# Moves the pointer onto the capsule at [param at].
func _hover(at: Vector3) -> void:
	await get_tree().create_timer(0.2).timeout
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_camera_3d().unproject_position(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
