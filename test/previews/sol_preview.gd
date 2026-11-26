extends Node
## The game started in Sol, docked at its home, Mars, to play the star system (F6) or
## capture it: its red sky and dying sun, its heat zone, abandoned Earth's smoke and the
## thin asteroid field. With "wide" after `--`, the camera pulls back over the whole
## system, and with a planet's name it looks at that planet: `capture <this scene> -- Earth`.
## `docked` after the name starts the bus docked there instead, the camera as in play, as
## `-- Earth docked` does to show abandoned Earth's station panel and the "(deserted)"
## under its name.

## How far the camera pulls back to show the whole system.
const WIDE_DISTANCE := 64.0
## How far it stands from a planet named after `--`.
const NEAR_DISTANCE := 9.0


# Before the solar system's own, so it starts the run in Sol.
func _enter_tree() -> void:
	var bus := find_child("Bus") as FrameshiftBus
	var args := OS.get_cmdline_user_args()
	var named := find_child(args[0]) as Planet if "docked" in args else null
	bus.start_planet = named if named else find_child("Mars") as Planet


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	await get_tree().process_frame
	var rig := find_child("CameraRig") as CameraRig
	for arg: String in args:
		var planet := find_child(arg) as Planet
		if planet and "docked" not in args:
			rig.set_distance(NEAR_DISTANCE)
			rig.move_to(planet.get_body_global_position())
			return
	if "wide" in args:
		rig.set_distance(WIDE_DISTANCE)
		rig.move_to((find_child("StarMap") as StarMap).get_current().global_position)
