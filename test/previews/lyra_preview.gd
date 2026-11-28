extends Node
## The game started in Lyra, docked at its home, Hither, to play the star system (F6) or
## capture it: its blue sky and star, its heat zone and the asteroid field. With "wide"
## after `--`, the camera pulls back over the whole system, and with a planet's name it
## looks at that planet: `capture <this scene> -- Cinder`. With `fly` before
## the name, the bus flies there from Hither instead, across the asteroid field, with the
## camera on the bus: `-- fly Janus`. With `warp`, the whole system shows and a second in
## the bus warps through Hither's gate to Yon: `-- warp`. With `warp` and a planet's name,
## the camera looks at that planet instead, so Yon is out of view and the camera glides
## there with the bus: `-- warp Hither`. With `gate`, the pointer rests on
## the station's Teleport button, showing the way through the gate: `-- gate`. With `stay`,
## the player has stayed after Lyra's promotion, so the goal panel offers the jump to Sol.
## With `hop`, the castaway's hop quest near Janus is under way and the camera looks at
## Cinder, Janus on its far side with the hop window closed; with `open` too, Janus is at
## its closest to the star, so the window is open: `-- hop open`.

## How far the camera pulls back to show the whole system.
const WIDE_DISTANCE := 68.0
## How far it stands from a planet named after `--`.
const NEAR_DISTANCE := 14.0
## How far it stands from Cinder for `hop`, and how often the castaway is said yes to, in
## seconds, until their quest is under way.
const HOP_DISTANCE := 26.0
const ANSWER_SECONDS := 1.75


# Before the solar system's own, so it starts the run in Lyra.
func _enter_tree() -> void:
	var bus := find_child("Bus") as FrameshiftBus
	bus.start_planet = find_child("Hither") as Planet


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	await get_tree().process_frame
	var rig := find_child("CameraRig") as CameraRig
	var star_map := find_child("StarMap") as StarMap
	if "hop" in args:
		_hop("open" in args)
		return
	for arg: String in args:
		var planet := find_child(arg) as Planet
		if planet and "fly" in args:
			var bus := find_child("Bus") as FrameshiftBus
			bus.plot_course(RouteStop.at_planet(planet))
			bus.frameshift_held = true
			(find_child("SolarSystem") as SolarSystem).open_bus()
			return
		if planet:
			rig.set_distance(NEAR_DISTANCE)
			rig.move_to(planet.get_body_global_position())
			if "warp" in args:
				_warp()
			return
	if "stay" in args:
		(find_child("Progression") as Progression).stay()
	if "wide" in args or "warp" in args:
		rig.set_distance(WIDE_DISTANCE)
		rig.move_to(star_map.get_current().global_position)
	if "gate" in args:
		await get_tree().create_timer(1.0).timeout
		var button := find_child("TeleportButton", true, false) as Control
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		motion.global_position = motion.position
		get_viewport().push_input(motion)
	if "warp" in args:
		_warp()


func _warp() -> void:
	await get_tree().create_timer(1.0).timeout
	var gate := WarpGate.of(find_child("Hither") as Planet)
	(find_child("SystemJump") as SystemJump).warp(gate, gate.partner)


# Takes on the castaway's hop quest and looks at Cinder, with Janus at its closest to the
# star when [param open], and on Cinder's far side otherwise.
func _hop(open: bool) -> void:
	var bus := find_child("Bus") as FrameshiftBus
	var field := find_child("CapsuleField") as CapsuleField
	field.enabled = false
	field.spawn(bus.global_position, Capsule.Contents.PASSENGER)
	var giver := find_child("QuestGiver") as QuestGiver
	while not giver.get_quest():
		await get_tree().create_timer(ANSWER_SECONDS).timeout
		(find_child("TransmissionPanel") as TransmissionPanel).accept()
	var cinder := find_child("Cinder") as Planet
	var janus := find_child("Janus") as Planet
	var turns := (cinder.start_angle + (180.0 if open else 0.0)) / 360.0
	janus.orbit_time = (turns + cinder.orbit_time / cinder.orbit_period) * janus.orbit_period
	var rig := find_child("CameraRig") as CameraRig
	rig.set_distance(HOP_DISTANCE)
	rig.move_to(cinder.get_body_global_position())
