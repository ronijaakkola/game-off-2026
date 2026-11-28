class_name BumpGoal
extends Goal
## A quest: pick up a [Vip] while the bus has too few seats free for them, with
## [member passenger] on board, so the VIP bumps them off to make room ([Seating]), which is
## what they want. It is done the moment they are kicked off: by a VIP, who kicks them
## first, or by The Boss boarding, which are the only kicks while the player's own is off
## ([member PassengerPanel.kicks_allowed]). It fails when they leave the bus any other way,
## as when they are left behind at a jump. A VIP picked up with room to spare changes
## nothing, and the next VIP gets another go.

var passenger: Passenger
## The bus's seats, so the player is told whether a VIP would fit. The quest sets it as it
## begins ([method BumpQuest.begin]).
var cabin: Cabin
# The seats free when the player was last told, so a change is told once.
var _shown_free := -1


func _init(who: Passenger) -> void:
	passenger = who


func get_text() -> String:
	return BumpQuest.ASK


func get_status() -> String:
	if not cabin:
		return ""
	if is_ready():
		return "Full enough: a VIP bumps %s" % passenger.name
	return "%d seats free: a VIP fits" % cabin.get_free_seats()


## Whether a VIP picked up now would have to bump someone: fewer seats free than they take.
func is_ready() -> bool:
	return cabin != null and cabin.get_free_seats() < Vip.TYPE.seats


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_complete()


func _on_left_behind(who: Passenger) -> void:
	if who == passenger:
		_fail("%s left the bus" % passenger.name)


func _on_bus_moved(_position: Vector3, _on_board: Array[Passenger], _in_flight: bool) -> void:
	var free := cabin.get_free_seats() if cabin else -1
	if free != _shown_free:
		_shown_free = free
		changed.emit()
