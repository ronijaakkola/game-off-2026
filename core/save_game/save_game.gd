extends Node
## The player's save game: their run, kept in [constant PATH] so it can be continued later.
## It holds the run as a plain Dictionary and knows nothing of what is in it; the game
## scene reads and writes it ([GameSaver]).
## The main menu starts a run, new or continued, and the game scene claims it when it
## starts ([method claim_run]). Only a claimed run is saved, so a game scene started any
## other way, by a test, a smoke run or F6, never reads or writes the file.
## On the web, saves are best effort: without persistent storage, the save lasts for the
## session only (docs/web-constraints.md).

const PATH := "user://save_game.json"
## Bumped when what the game writes changes so that an older save can't be read: a save
## of another version counts as none.
const VERSION := 1

## Where the save is: [constant PATH]. Tests run in the player's own user folder, so a test
## that saves points it at a file of its own and puts it back after.
var path := PATH

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


# The saved run, or empty when there is none, it can't be read or it is of another version.
func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var run := parsed as Dictionary if parsed is Dictionary else {}
	if int(run.get("version", 0)) != VERSION:
		return {}
	return run
