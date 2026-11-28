class_name BossErrand
extends Node
## The errand The Boss has the player run once the [Stargate] is built and they are on
## board ([BossPickUp]): stop at [member planet], which is in another star system, so the
## bus has to go through the stargate ([StarTravel]). The goal panel shows it as a quest,
## and the star chart shows it on that planet's star. Once the bus is docked there, it is
## done: The Boss comes back dressed for the board, in a bow tie and with a briefcase
## ([method BossPassenger.dress_up]). [BossPickUp] keeps whether it is done for a save.

## Seconds the quest's row stays, ticked, once it is done.
const DONE_SECONDS := 2.5

@export var boss_pick_up: BossPickUp
@export var bus: FrameshiftBus
@export var cabin: Cabin
## Shows the quest.
@export var goal_panel: GoalPanel
## Where The Boss's errand is.
@export var planet: Planet

var _quest: BossErrandQuest


func _process(_delta: float) -> void:
	if not planet:
		return
	if not _quest:
		var boss := _find_boss()
		if boss and boss_pick_up.is_built() and not boss_pick_up.is_errand_done():
			_give(boss)
		return
	var there := bus.is_at_planet() and bus.get_docked_planet() == planet
	if there and _quest.goal.is_active() and not cabin.is_stopping():
		_finish()


## The errand while it is under way, or null.
func get_quest() -> Quest:
	return _quest if _quest and _quest.goal.is_active() else null


func _find_boss() -> Passenger:
	for passenger: Passenger in cabin.get_passengers():
		if BossPassenger.is_boss(passenger):
			return passenger
	return null


func _give(boss: Passenger) -> void:
	_quest = BossErrandQuest.new()
	_quest.passenger = boss
	_quest.planet = planet
	_quest.accept()
	goal_panel.show_quest(_quest)


# The bus is there with The Boss: they come back dressed, and the quest goes.
func _finish() -> void:
	var quest := _quest
	quest.arrive()
	BossPassenger.dress_up(quest.passenger)
	boss_pick_up.finish_errand()
	await get_tree().create_timer(DONE_SECONDS, false).timeout
	goal_panel.hide_quest(quest)
	_quest = null
