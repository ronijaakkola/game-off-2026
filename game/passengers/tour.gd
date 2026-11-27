class_name Tour
extends RefCounted
## The stops a VIP wants to be taken to, in order ([member Passenger.tour]). The bus docks
## at each in turn with them on board, and they get off at the last. Their
## [member Passenger.destination] is the stop they are on.

## Every stop, in order.
var stops: Array[Planet] = []
## How many of them the bus has made with them on board.
var done := 0


func _init(planets: Array[Planet], made := 0) -> void:
	stops = planets
	done = made


## The tour [method to_save] gave, with its stops found by name in [param planets]. Null
## when it names none, or one that isn't there.
static func from_save(saved: Dictionary, planets: Dictionary[String, Planet]) -> Tour:
	var found: Array[Planet] = []
	for stop: Variant in saved.get("stops", []):
		if not planets.has(str(stop)):
			return null
		found.append(planets[str(stop)])
	return null if found.is_empty() else Tour.new(found, int(saved.get("done", 0)))


## The stop they are on, or the last one once the tour is over.
func get_next() -> Planet:
	return stops[mini(done, stops.size() - 1)]


## Whether the stop they are on is where they get off.
func is_last() -> bool:
	return done >= stops.size() - 1


## The bus made the stop they were on. False when that was the last.
func advance() -> bool:
	done = mini(done + 1, stops.size())
	return done < stops.size()


## The stops by name and how many are made, for a save game.
func to_save() -> Dictionary:
	var names: Array[String] = []
	for stop: Planet in stops:
		names.append(String(stop.name))
	return {"stops": names, "done": done}
