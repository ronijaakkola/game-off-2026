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
## On the web, saves are best effort: without persistent storage, the save lasts for the
## session only (docs/web-constraints.md).

const PATH := "user://save_game.json"
## Where whether the player has been through the tutorial is kept.
const TUTORIAL_PATH := "user://tutorial.cfg"
## Where the feature hints the player has closed are kept.
const HINTS_PATH := "user://feature_hints.cfg"
## Bumped when what the game writes changes so that an older save can't be read: a save
## of another version counts as none.
const VERSION := 1

## Where the save is: [constant PATH]. Tests run in the player's own user folder, so a test
## that saves points it at a file of its own and puts it back after.
var path := PATH
## Where whether the player has been through the tutorial is: [constant TUTORIAL_PATH],
## pointed elsewhere by a test the way [member path] is.
var tutorial_path := TUTORIAL_PATH
## Where the feature hints the player has closed are: [constant HINTS_PATH], pointed
## elsewhere by a test the way [member path] is.
var hints_path := HINTS_PATH

# The run the main menu started, until the game claims it: whether there is one, and the
# saved run it continues, empty for a new one.
var _started := false
var _pending: Dictionary = {}


## Whether there is a save to continue.
func has_save() -> bool:
	return not _read().is_empty()


## Starts a new run for the next game scene. The save stays until the new run first saves
## over it, so a New game left at once loses nothing.
func start_new() -> void:
	_started = true
	_pending = {}


## Starts the next game scene from the save.
func continue_saved() -> void:
	_started = true
	_pending = _read()


## Whether the main menu started a run that no game scene has claimed yet.
func has_started_run() -> bool:
	return _started


## Takes the run the main menu started: the saved run to continue, or an empty one for a
## new run, or when none was started. After it, there is none to claim.
func claim_run() -> Dictionary:
	var run := _pending
	_started = false
	_pending = {}
	return run


## Saves [param run] over the save.
func write(run: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_warning("Couldn't save the game: %s" % error_string(FileAccess.get_open_error()))
		return
	var saved := run.duplicate()
	saved["version"] = VERSION
	file.store_string(JSON.stringify(saved))
	# Closing it is what saves it on the web.
	file.close()


## Deletes the save.
func delete() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Whether the player has been through the tutorial, done or skipped, in any run.
func is_tutorial_done() -> bool:
	var file := ConfigFile.new()
	if file.load(tutorial_path) != OK:
		return false
	return bool(file.get_value("tutorial", "done", false))


## Keeps that the player has been through the tutorial.
func mark_tutorial_done() -> void:
	var file := ConfigFile.new()
	file.set_value("tutorial", "done", true)
	var error := file.save(tutorial_path)
	if error != OK:
		push_warning("Couldn't save the tutorial as done: %s" % error_string(error))


## Forgets that the player has been through the tutorial, so the next New game has it again.
func forget_tutorial() -> void:
	if FileAccess.file_exists(tutorial_path):
		DirAccess.remove_absolute(tutorial_path)


## Whether the player has closed the feature hint [param hint], in any run.
func has_seen_hint(hint: StringName) -> bool:
	var file := ConfigFile.new()
	if file.load(hints_path) != OK:
		return false
	return bool(file.get_value("seen", hint, false))


## Keeps that the player has closed the feature hint [param hint].
func mark_hint_seen(hint: StringName) -> void:
	var file := ConfigFile.new()
	# Missing the first time: it starts empty.
	file.load(hints_path)
	file.set_value("seen", hint, true)
	var error := file.save(hints_path)
	if error != OK:
		push_warning("Couldn't save the hint as seen: %s" % error_string(error))


## Forgets every feature hint the player has closed, so each shows again.
func forget_hints() -> void:
	if FileAccess.file_exists(hints_path):
		DirAccess.remove_absolute(hints_path)


# The saved run, or empty when there is none, it can't be read or it is of another version.
func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var run := parsed as Dictionary if parsed is Dictionary else {}
	if int(run.get("version", 0)) != VERSION:
		return {}
	return run
