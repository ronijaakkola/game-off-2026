class_name Campaign
## The levels, played in order, and how far through them the player has got. A level is a
## stage of the one run, in its own star system: Level 1 in Vela, Level 2 in Lyra, Level 3 in
## Sol. It is done once a promotion there opens the next system, and the next level is
## open once the one before is done. The run as each level began is kept, so a level can be
## restarted or played again with what was earned before it; starting one over replaces the
## run, and how far the player has got stays.
## It keeps nothing itself: the run and the campaign's record are in [code]SaveGame[/code],
## and the game scene adds to the record at every save ([method record]).

const LEVELS: Array[Level] = [
	preload("res://shared/level_art/level_1.tres"),
	preload("res://shared/level_art/level_2.tres"),
	preload("res://shared/level_art/level_3.tres"),
]
const GAME_SCENE := "res://game/solar_system/solar_system.tscn"


## [param level]'s number, from 1.
static func number(level: Level) -> int:
	return LEVELS.find(level) + 1


## The level the saved run is in, or null without a save. A save from before saves kept
## their star system counts as Level 1.
static func get_in_progress() -> Level:
	if not SaveGame.has_save():
		return null
	var system := SavedStarMap.get_system(SavedStarMap.of(SaveGame.get_saved_run()))
	return LEVELS[0] if system.is_empty() else find(system)


## Whether the player has been promoted out of [param level], in this run or an earlier one.
static func is_done(level: Level) -> bool:
	return count_done() >= number(level)


## Whether [param level] can be played: the first, or one whose level before it is done.
static func is_open(level: Level) -> bool:
	return number(level) == 1 or count_done() >= number(level) - 1


## How many levels the player has finished, in this run or an earlier one.
static func count_done() -> int:
	var done := int(SaveGame.read_campaign().get("done", 0))
	# A save from before the campaign's record knows only how far its run got.
	var star_map := SavedStarMap.of(SaveGame.get_saved_run())
	return maxi(done, SavedStarMap.count_done(star_map, LEVELS.size()))


## Whether anything is kept that [method reset] would delete.
static func has_progress() -> bool:
	return SaveGame.has_save() or not SaveGame.read_campaign().is_empty()


## Whether playing [param level] would replace the run in progress, rather than continue
## it: Level 1 or a level with a kept start, while the run is in another level.
static func replaces_run(level: Level) -> bool:
	var in_progress := get_in_progress()
	if in_progress == null or in_progress == level:
		return false
	return number(level) == 1 or not _kept_start(level).is_empty()


## Forgets the run and how far the player has got, so only Level 1 is open.
static func reset() -> void:
	SaveGame.delete()


## Plays [param level]: the run where it stands when it is in progress, else from where the
## level began. Level 1 begins a new run, on the tutorial if [param tutorial]. A level the
## run hasn't begun yet continues the run, which leads there.
static func play(level: Level, tutorial := false) -> void:
	if level == get_in_progress():
		SaveGame.continue_saved()
	else:
		_start(level, tutorial)
	SceneFlow.go_to(GAME_SCENE, level)


## Starts [param level] over from where it began, as [method play] starts one not in progress.
static func restart(level: Level, tutorial := false) -> void:
	_start(level, tutorial)
	SceneFlow.go_to(GAME_SCENE, level)


## Adds a save of the [param run] to the record: [param done] levels finished, and, when
## [param entered] says the run has just come into [param system], the run as its level
## began.
static func record(run: Dictionary, system: String, done: int, entered: bool) -> void:
	var campaign := SaveGame.read_campaign()
	campaign["done"] = maxi(int(campaign.get("done", 0)), done)
	var level := find(system)
	var starts: Dictionary = campaign.get("starts", {})
	if entered and level and number(level) > 1:
		starts[str(number(level))] = run
	campaign["starts"] = starts
	SaveGame.write_campaign(campaign)


# A kept start takes over the save at once, as a new run does, so quitting straight after
# never brings back the run it replaced.
static func _start(level: Level, tutorial: bool) -> void:
	var start := _kept_start(level)
	if number(level) == 1:
		SaveGame.start_new_with_tutorial(tutorial)
	elif not start.is_empty():
		SaveGame.write(start)
		SaveGame.start_run(start)
	elif SaveGame.has_save():
		SaveGame.continue_saved()
	else:
		SaveGame.start_new()


# The run as it entered [param level], or empty when none is kept.
static func _kept_start(level: Level) -> Dictionary:
	var starts: Dictionary = SaveGame.read_campaign().get("starts", {})
	return starts.get(str(number(level)), {})


## The level played in [param system], by its node name, or null.
static func find(system: String) -> Level:
	for level: Level in LEVELS:
		if level.star_system == system:
			return level
	return null
