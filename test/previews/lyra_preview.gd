extends Node
## The game started in Lyra, docked at its home, Hither, to play the star system (F6) or
## capture it: its blue sky and star, its heat zone and the asteroid field. With "wide"
## after `--`, the camera pulls back over the whole system, and with a planet's name it
## looks at that planet: `capture <this scene> -- Cinder`. With `fly` before
## the name, the bus flies there from Hither instead, across the asteroid field, with the
## camera on the bus: `-- fly Janus`. With `warp`, the whole system shows and a second in
## the bus warps through Hither's gate to Yon: `-- warp`. With `gate`, the pointer rests on
## the station's Teleport button, showing the way through the gate: `-- gate`. With `stay`,
## the player has stayed after Lyra's promotion, so the goal panel offers the jump to Sol.

## How far the camera pulls back to show the whole system.
const WIDE_DISTANCE := 68.0
## How far it stands from a planet named after `--`.
const NEAR_DISTANCE := 14.0


# Before the solar system's own, so it starts the run in Lyra.
func _enter_tree() -> void:
	var bus := find_child("Bus") as FrameshiftBus
	bus.start_planet = find_child("Hither") as Planet


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	await get_tree().process_frame
	var rig := find_child("CameraRig") as CameraRig
	var star_map := find_child("StarMap") as StarMap
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
		await get_tree().create_timer(1.0).timeout
		var gate := WarpGate.of(find_child("Hither") as Planet)
		(find_child("SystemJump") as SystemJump).warp(gate, gate.partner)
