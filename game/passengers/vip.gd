class_name Vip
## A VIP: a passenger who calls the bus to pick them up at a planet and take them on a
## [Tour] of several stops in order ([VipCalls]). They are gold, a colour no race has, with
## a star badge, and their photo shines ([PhotoShine]). A save keeps a look as one of its
## race's heads, so a VIP from a save is dressed again ([method dress]).

const TYPE: PassengerType = preload("res://game/passengers/types/vip.tres")
const SKIN := Color(1.0, 0.76, 0.16)
## What stands behind their portrait, whatever their race.
const BACKDROP := Color(0.42, 0.2, 0.52)
## The gold of their group and their stops on the On board panel.
const GOLD := Color(1.0, 0.796, 0.239)


## Makes [param passenger] gold.
static func dress(passenger: Passenger) -> void:
	passenger.look.skin_color = SKIN


## [param seconds] as minutes and seconds ("1:05"), rounded up, for a VIP's timers.
static func format_time(seconds: float) -> String:
	var whole := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [whole / 60, whole % 60]


## Whether [param passenger] is a VIP.
static func is_vip(passenger: Passenger) -> bool:
	return passenger != null and passenger.type == TYPE
