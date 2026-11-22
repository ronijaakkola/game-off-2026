extends Node
## The player's save game: their run, kept in [constant PATH] so it can be continued later.
## It holds the run as a plain Dictionary and knows nothing of what is in it; the game
## scene reads and writes it ([GameSaver]).
## The main menu starts a run, new or continued, and the game scene claims it when it
## starts ([method claim_run]). Only a claimed run is saved, so a game scene started any
## other way, by a test, a smoke run or F6, never reads or writes the file.
## It also keeps, in [constant TUTORIAL_PATH], whether the player has been through the
## tutorial: it outlives the run, so a New game after it starts without the tutorial.
## And it keeps, in [constant HINTS_PATH], which feature hints the player has closed, so
## each shows once ([FeatureHints]) until the player deletes their save data.
## And it keeps the campaign's record in [constant CAMPAIGN_PATH], which outlives the run:
## a replayed level starts the run over and keeps how far the player has got. As with the
## run, it holds a plain Dictionary and knows nothing of what is in it ([Campaign]).
## On the web, saves are best effort: without persistent storage, the save lasts for the
## session only (docs/web-constraints.md).

const PATH := "user://save_game.json"
## Where whether the player has been through the tutorial is kept.
const TUTORIAL_PATH := "user://tutorial.cfg"
## Where the feature hints the player has closed are kept.
const HINTS_PATH := "user://feature_hints.cfg"
## Where the campaign's record is kept.
const CAMPAIGN_PATH := "user://campaign.json"
## Bumped when what the game writes changes so that an older save can't be read: a save
## of another version counts as none.
const VERSION := 1

## Every file the save game keeps, each deleted by [method delete]. A new file's path
## goes here too, or deleting the save data leaves it behind (save_game_test checks).
const FILES: Array[String] = [PATH, TUTORIAL_PATH, HINTS_PATH, CAMPAIGN_PATH]
const _PLAYER_FOLDER := "user://"

# What each file's path starts with in place of [constant _PLAYER_FOLDER]: the player's
# own, or a test's prefix ([method use_test_files]).
var _prefix := _PLAYER_FOLDER

# The run the main menu started, until the game claims it: whether there is one, and the
# saved run it continues, empty for a new one.
var _started := false
var _pending: Dictionary = {}
# Whether the started run opens on the tutorial.
var _tutorial := false


## Whether there is a save to continue.
func has_save() -> bool:
	return not _read().is_empty()


## The saved run, without starting it: empty when there is none.
func get_saved_run() -> Dictionary:
	return _read()


## Starts a new run for the next game scene, with the tutorial until the player has been
## through it. The save stays until the new run first saves over it, so a new run left at
## once loses nothing.
func start_new() -> void:
	start_new_with_tutorial(not is_tutorial_done())


## Starts a new run for the next game scene, opening on the tutorial if [param tutorial].
func start_new_with_tutorial(tutorial: bool) -> void:
	_started = true
	_pending = {}
	_tutorial = tutorial


## Starts the next game scene from the save.
func continue_saved() -> void:
	start_run(_read())


## Starts the next game scene from [param run], a run as [method write] took it, such as
## where a level began.
func start_run(run: Dictionary) -> void:
	_started = true
	_pending = run.duplicate(true)
	_tutorial = false


## Whether the run the main menu started opens on the tutorial.
func wants_tutorial() -> bool:
	return _started and _tutorial


## Whether the main menu started a run that no game scene has claimed yet.
func has_started_run() -> bool:
	return _started


## Takes the run the main menu started: the saved run to continue, or an empty one for a
## new run, or when none was started. After it, there is none to claim.
func claim_run() -> Dictionary:
	var run := _pending
	_started = false
	_pending = {}
	_tutorial = false
	return run


## Saves [param run] over the save.
func write(run: Dictionary) -> void:
	_write_json(PATH, run)


## The campaign's record, empty when there is none.
func read_campaign() -> Dictionary:
	return _read_json(CAMPAIGN_PATH)


## Saves [param campaign] as the campaign's record.
func write_campaign(campaign: Dictionary) -> void:
	_write_json(CAMPAIGN_PATH, campaign)


## Deletes the save data: the run, whether the player has been through the tutorial and
## which feature hints they have closed, so the game starts as on a first visit. It is
## the only way to delete the run, so nothing deletes one without the others.
func delete() -> void:
	for file: String in FILES:
		if FileAccess.file_exists(_at(file)):
			DirAccess.remove_absolute(_at(file))


## Points every file in [constant FILES] at a test's own copy, named after [param suite],
## so the test never reads or deletes the player's: tests run in the player's own user
## folder. [method use_player_files] deletes the copies and points back.
func use_test_files(suite: String) -> void:
	_prefix = "%stest_%s_" % [_PLAYER_FOLDER, suite]


## Deletes a test's copies ([method use_test_files]) and points back at the player's files.
func use_player_files() -> void:
	if _prefix != _PLAYER_FOLDER:
		delete()
	_prefix = _PLAYER_FOLDER


## Whether the player has been through the tutorial, done or skipped, in any run.
func is_tutorial_done() -> bool:
	var file := ConfigFile.new()
	if file.load(_at(TUTORIAL_PATH)) != OK:
		return false
	return bool(file.get_value("tutorial", "done", false))


## Keeps that the player has been through the tutorial.
func mark_tutorial_done() -> void:
	var file := ConfigFile.new()
	file.set_value("tutorial", "done", true)
	var error := file.save(_at(TUTORIAL_PATH))
	if error != OK:
		push_warning("Couldn't save the tutorial as done: %s" % error_string(error))


## Whether the player has closed the feature hint [param hint], in any run.
func has_seen_hint(hint: StringName) -> bool:
	var file := ConfigFile.new()
	if file.load(_at(HINTS_PATH)) != OK:
		return false
	return bool(file.get_value("seen", hint, false))


## Keeps that the player has closed the feature hint [param hint].
func mark_hint_seen(hint: StringName) -> void:
	var file := ConfigFile.new()
	# Missing the first time: it starts empty.
	file.load(_at(HINTS_PATH))
	file.set_value("seen", hint, true)
	var error := file.save(_at(HINTS_PATH))
	if error != OK:
		push_warning("Couldn't save the hint as seen: %s" % error_string(error))


## Forgets every feature hint the player has closed, so each shows again.
func forget_hints() -> void:
	if FileAccess.file_exists(_at(HINTS_PATH)):
		DirAccess.remove_absolute(_at(HINTS_PATH))


# The saved run, or empty when there is none, it can't be read or it is of another version.
func _read() -> Dictionary:
	return _read_json(PATH)


# What [param path], one of [constant FILES], holds, or empty when it isn't there, can't be
# read or is of another version.
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(_at(path)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_at(path)))
	var data := parsed as Dictionary if parsed is Dictionary else {}
	if int(data.get("version", 0)) != VERSION:
		return {}
	return data


# Saves [param data] in [param path], one of [constant FILES], with the version.
func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(_at(path), FileAccess.WRITE)
	if not file:
		push_warning("Couldn't save the game: %s" % error_string(FileAccess.get_open_error()))
		return
	var saved := data.duplicate()
	saved["version"] = VERSION
	file.store_string(JSON.stringify(saved))
	# Closing it is what saves it on the web.
	file.close()


# Where [param file], one of [constant FILES], is now.
func _at(file: String) -> String:
	return file.replace(_PLAYER_FOLDER, _prefix)
