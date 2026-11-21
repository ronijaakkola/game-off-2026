extends Node
## The solar system with every kind of notice stacked above the bus bars, as in the design:
## a closable tutorial at the bottom, then info, warning, the
## out of fuel tow offer and the calls on top: The Boss, the mechanic unknown and then known,
## and a passenger with a decline button. `-- dismiss` closes the info notice 1 s in, so
## the ones above it glide down (about 1.5 s in, `--frames 90`).


func _ready() -> void:
	var notices := $SolarSystem/Hud/Notices as NoticeStack
	notices.push("Right-click a planet to add it to the route.", Notice.Kind.TUTORIAL, true)
	var info := notices.push("The tank is full.")
	notices.push("Fuel is running low.", Notice.Kind.WARNING)
	notices.offer_tow(TowDispatch.TOW_FEE)
	var boss := Transmission.from_boss()
	boss.caller_name = "Your Boss"
	notices.announce_transmission(boss)
	notices.announce_transmission(Transmission.from_mechanic(), false)
	notices.announce_transmission(Transmission.from_mechanic())
	var passenger := Transmission.new()
	passenger.caller_name = "Reizhis"
	passenger.look = AlienLook.random(RandomNumberGenerator.new(), Race.Type.GREEN)
	passenger.race = Race.Type.GREEN
	notices.announce_transmission(passenger, true, true)
	if "dismiss" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		info.dismiss()
