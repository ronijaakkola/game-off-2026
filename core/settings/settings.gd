extends Node
## The player's settings: preferences only, never game progress.
## Every change is applied at once, and saved to [constant PATH] once changes stop for
## [constant SAVE_DELAY] seconds, so dragging a slider writes the file once. On the web,
## saves are best effort: without persistent storage, settings last for the session only.
## Every public var is a setting: loaded at start and saved with the rest. Its setter applies
## the value and calls [method _queue_save]. A var that isn't a setting starts with [code]_[/code],
## the only way to keep it out of the file.

const PATH := "user://settings.cfg"
const SECTION := "settings"
const SAVE_DELAY := 0.4

var master_volume := 0.8:
	set(value):
		master_volume = value
		Audio.set_volume(Audio.Bus.MASTER, value)
		_queue_save()
var music_volume := 0.6:
	set(value):
		music_volume = value
		Audio.set_volume(Audio.Bus.MUSIC, value)
		_queue_save()
var sfx_volume := 0.8:
	set(value):
		sfx_volume = value
		Audio.set_volume(Audio.Bus.SFX, value)
		_queue_save()
var reduce_motion := false:
	set(value):
		reduce_motion = value
		_queue_save()

var _loaded := false
var _save_timer := Timer.new()


func _ready() -> void:
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	# Settings change in the pause menu, and a hit-stop may slow time.
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.ignore_time_scale = true
	_save_timer.timeout.connect(_save)
	add_child(_save_timer)

	var file := ConfigFile.new()
	file.load(PATH)  # A missing file leaves the defaults.
	# Assigning every key, defaults included, runs the setters, which apply the values.
	for key: String in get_names():
		set(key, file.get_value(SECTION, key, get(key)))
	_loaded = true


## The name of every setting, read from this script's public vars so no list can miss one.
func get_names() -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in (get_script() as Script).get_script_property_list():
		var property_name: String = property.name
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not property_name.begins_with("_"):
			names.append(property_name)
	return names


# Quitting from the game, the web build included, writes a change still waiting.
# Closing the browser tab doesn't.
func _exit_tree() -> void:
	if not _save_timer.is_stopped():
		_save_timer.stop()
		_save()


# Each change restarts the wait, so a burst of changes saves once.
func _queue_save() -> void:
	if _loaded:
		_save_timer.start()


func _save() -> void:
	var file := ConfigFile.new()
	for key: String in get_names():
		file.set_value(SECTION, key, get(key))
	file.save(PATH)
