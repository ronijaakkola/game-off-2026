extends SceneTree
## Saves each scene and resource named after -- the way the editor's save does, so Godot
## fills in a missing uid or unique_id. Run through `uv run tools/check.py ids`, which
## passes the files in dependency order and runs this with --editor: without it, saving
## drops every uid in the file.
##
## It reads and saves every file in _initialize(), as the editor does once it has started:
## a script that isn't @tool runs as a placeholder, which keeps the scene's values and
## leaves out one equal to its export's default. Not in _init(): there the autoloads aren't
## globals yet, so every script that names one fails to compile, and packing writes its
## exports as null. A placeholder drops a value whose export default is a literal of
## another type, like `var names: PackedStringArray = ["Passenger"]` (an Array), as the
## editor's own save would. check.py ids compares tools/resource_dump.gd's dumps from
## before and after the resave, and puts the files back if anything but an id changed, or
## if a script failed to compile here.

var _failures := 0


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	for path: String in paths:
		var resource := _read(path)
		if resource == null:
			_failures += 1
			printerr("FAILED: ", path, " (could not load or pack it)")
			continue
		var error := ResourceSaver.save(resource, path)
		if error != OK:
			_failures += 1
			printerr("FAILED: ", path, " (", error_string(error), ")")
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
