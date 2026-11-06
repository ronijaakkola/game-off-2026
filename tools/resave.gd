extends SceneTree
## Saves each scene and resource named after -- the way the editor's save does, so Godot
## fills in a missing uid or unique_id. Run through `uv run tools/check.py ids`, which
## passes the files in dependency order and runs this with --editor: without it, saving
## drops every uid in the file.
##
## It reads every file in _init() and saves in _initialize(), because neither works in the
## other. By _initialize() the editor has turned scripting off, so a script that isn't
## @tool runs as a placeholder, and a placeholder only keeps a value that compares unequal
## to the export's default. A default written as a literal of another type, like
## `var names: PackedStringArray = ["Passenger"]` (an Array), compares as neither equal nor
## unequal to the file's PackedStringArray, so the value was dropped without an error.
## In _init() scripting is still on and every script runs as itself, as in the game, but
## the editor can't assign uids yet. The cache mode makes no difference.
## check.py ids compares tools/resource_dump.gd's dumps from before and after the resave,
## and puts the files back if anything but an id changed.

var _loaded: Array[Resource] = []
var _failures := 0


func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		var resource := _read(path)
		if resource == null:
			_failures += 1
			printerr("FAILED: ", path, " (could not load or pack it)")
		_loaded.append(resource)


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	for index: int in paths.size():
		if _loaded[index] == null:
			continue
		var error := ResourceSaver.save(_loaded[index], paths[index])
		if error != OK:
			_failures += 1
			printerr("FAILED: ", paths[index], " (", error_string(error), ")")
	print("saved %d, failures: %d" % [paths.size() - _failures, _failures])
	quit(1 if _failures > 0 else 0)


func _read(path: String) -> Resource:
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var scene := resource as PackedScene
	if scene == null:
		return resource
	# The editor saves a scene by packing the open instance, and packing is what
	# assigns unique_ids. Saving the loaded PackedScene as it is would keep the gaps.
	var root := scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if root == null:
		return null
	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	return packed if error == OK else null
