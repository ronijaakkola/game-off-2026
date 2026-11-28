class_name BossErrandQuest
extends ErrandQuest
## The Boss's errand once the [Stargate] is built ([BossErrand]): stop at
## [member ErrandQuest.planet], in another star system, with them on board. It has no
## timer, pays nothing, and is done as the bus docks there ([method arrive]). Whoever gives
## it sets the passenger and the planet first.


func restore(saved: Dictionary, who: Passenger, planets: Dictionary[String, Planet]) -> bool:
	planet = planets.get(saved.get("planet", ""))
	if not planet:
		return false
	passenger = who
	accept()
	load_save(saved)
	return true


func get_kind() -> String:
	return "boss_errand"


func accept() -> void:
	goal = StopGoal.new(planet)


## The bus is there: the quest is done.
func arrive() -> void:
	if goal and goal.is_active():
		(goal as StopGoal).reach()


## Done once the bus is there.
class StopGoal:
	extends Goal

	var _planet: Planet

	func _init(at: Planet) -> void:
		_planet = at

	func get_text() -> String:
		return "Stop at %s for The Boss" % _planet.display_name

	## Marks it done.
	func reach() -> void:
		_complete()
