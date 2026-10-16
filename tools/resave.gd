extends SceneTree
## Saves each scene and resource named after -- the way the editor's save does, so Godot
## fills in a missing uid or unique_id. Run through `uv run tools/check.py ids`, which
## passes the files in dependency order and runs this with --editor: without it, saving
## drops every uid in the file.


func _initialize() -> void:
	var failures := 0
	for path: String in OS.get_cmdline_user_args():
		var error := _save(path)
		if error != OK:
			failures += 1
			printerr("FAILED: ", path, " (", error_string(error), ")")
	print("saved %d, failures: %d" % [OS.get_cmdline_user_args().size() - failures, failures])
	quit(1 if failures > 0 else 0)


func _save(path: String) -> Error:
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return ERR_CANT_OPEN
	var scene := resource as PackedScene
	if scene != null:
		# The editor saves a scene by packing the open instance, and packing is what
		# assigns unique_ids. Saving the loaded PackedScene as it is would keep the gaps.
		var root := scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		if root == null:
			return ERR_CANT_CREATE
		resource = PackedScene.new()
		var error := (resource as PackedScene).pack(root)
		root.free()
		if error != OK:
			return error
	return ResourceSaver.save(resource, path)
