extends SceneTree
## Loads every script, scene, resource and .glb model outside addons/ and quits with 1 if any
## script fails to compile or any scene, resource or model fails to load.
## Run through `uv run tools/check.py load`, which also checks the summary line.


func _initialize() -> void:
	var me: String = (get_script() as Script).resource_path
	var checked := 0
	var failures := 0
	for path: String in _files("res://"):
		if path == me:
			continue
		checked += 1
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var script := resource as GDScript
		if resource == null or (script != null and not script.can_instantiate()):
			failures += 1
			printerr("FAILED: ", path)
	print("checked %d, failures: %d" % [checked, failures])
	quit(1 if failures > 0 else 0)


func _files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		if dir_name.begins_with(".") or (dir_path == "res://" and dir_name == "addons"):
			continue
		found.append_array(_files(dir_path.path_join(dir_name)))
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() in ["gd", "tscn", "tres", "glb"]:
			found.append(dir_path.path_join(file_name))
	return found
