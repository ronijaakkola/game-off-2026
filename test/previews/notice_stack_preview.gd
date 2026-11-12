extends Node
## The solar system with every kind of notice stacked above the bus bars, as in the design:
## the course hint (tutorial) at the bottom, then a closable tutorial, info, warning, the
## out of fuel tow offer and the incoming transmission on top. `-- dismiss` closes the info
## notice 1 s in, so the ones above it glide down (about 1.5 s in, `--frames 90`).


func _ready() -> void:
	var notices := $SolarSystem/Hud/Notices as NoticeStack
	notices.push("Right-click a planet to add it to the route.", Notice.Kind.TUTORIAL, true)
	var info := notices.push("The tank is full.")
	notices.push("Fuel is running low.", Notice.Kind.WARNING)
	notices.offer_tow(TowDispatch.TOW_FEE)
	notices.announce_transmission()
	if "dismiss" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		info.dismiss()
