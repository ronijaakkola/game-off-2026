class_name SavedStarMap
## How a save keeps the star map: how many systems are open, whether they are joined, and the
## system the bus works in, by name. [StarMap] writes and reads it in the game, and
## [Campaign] reads it in the menus to tell which level a saved run is in and how far it got.
## Every key of it is here, so the two read one shape. It names no other game script, so the
## menus that read it load nothing of the game.

## The run's key for the star map's part.
const KEY := "star_map"


## The star map's part of [param run], a run as [GameSaver] saved it: empty without one.
static func of(run: Dictionary) -> Dictionary:
	return run.get(KEY, {})


## The star map's part of a save: [param opened] systems open, [param joined] or not, and the
## bus in [param system].
static func make(opened: int, joined: bool, system: String) -> Dictionary:
	return {"opened": opened, "joined": joined, "system": system}


## How many systems [param saved] has open, from 1.
static func get_opened(saved: Dictionary) -> int:
	return int(saved.get("opened", 1))


static func is_joined(saved: Dictionary) -> bool:
	return bool(saved.get("joined", false))


## The system the bus worked in, by name, or empty for a save from before saves kept it.
static func get_system(saved: Dictionary) -> String:
	return str(saved.get("system", ""))


## How many of [param system_count] systems [param saved] has been promoted out of: each
## opened the next, and the last joined them.
static func count_done(saved: Dictionary, system_count: int) -> int:
	return system_count if is_joined(saved) else get_opened(saved) - 1
