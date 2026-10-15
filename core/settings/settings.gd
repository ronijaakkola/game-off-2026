extends Node
## The player's settings: preferences only, never game progress.
## Every change is applied and saved to [constant PATH] at once. On the web, saves are
## best effort: without persistent storage, settings last for the session only.

const PATH := "user://settings.cfg"
const SECTION := "settings"
const KEYS: Array[String] = ["master_volume", "music_volume", "sfx_volume", "reduce_motion"]

var master_volume := 0.8:
	set(value):
		master_volume = value
		_set_bus_volume("Master", value)
		_save()
var music_volume := 0.6:
	set(value):
		music_volume = value
		_set_bus_volume("Music", value)
		_save()
var sfx_volume := 0.8:
	set(value):
		sfx_volume = value
		_set_bus_volume("SFX", value)
		_save()
var reduce_motion := false:
	set(value):
		reduce_motion = value
		_save()

var _loaded := false


func _ready() -> void:
	var file := ConfigFile.new()
	file.load(PATH)  # A missing file leaves the defaults.
	# Assigning every key, defaults included, runs the setters, which apply the values.
	for key: String in KEYS:
		set(key, file.get_value(SECTION, key, get(key)))
	_loaded = true


func _set_bus_volume(bus: String, linear: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), linear)


func _save() -> void:
	if not _loaded:
		return
	var file := ConfigFile.new()
	for key: String in KEYS:
		file.set_value(SECTION, key, get(key))
	file.save(PATH)
