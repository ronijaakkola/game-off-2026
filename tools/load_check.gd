extends SceneTree
## Loads every script, scene, resource and .glb model outside addons/ and quits with 1 if any
## script fails to compile, any scene, resource or model fails to load, or a scene or
## resource stores a property that what it sets no longer has.
## Run through `uv run tools/check.py load`, which also checks the summary line.

# A sub-resource or the main resource of a .tscn or .tres, and the id of a sub-resource.
const SECTION := "^\\[(sub_resource|resource)\\b([^\\n]*)\\]$"
const SECTION_ID := '\\bid="([^"]+)"'
# A stored property: its name at the start of a line, as Godot writes it.
const STORED := "^([A-Za-z_][\\w/]*) = "


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
			continue
		var dropped := _dropped_properties(path, resource)
		if not dropped.is_empty():
			failures += 1
			for line: String in dropped:
				printerr("FAILED: ", line)
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


# Each property the file at [param path] stores on a node or resource that has no such
# property, as after renaming or removing an @export. Godot drops the value without a word
# on load, so the node or resource runs on its script's default.
func _dropped_properties(path: String, loaded: Resource) -> PackedStringArray:
	if path.get_extension() not in ["tscn", "tres"]:
		return PackedStringArray()
	var dropped := PackedStringArray()
	var by_id: Dictionary[String, Resource] = {}
	_collect(loaded, path, by_id)
	var scene := loaded as PackedScene
	if scene:
		var state := scene.get_state()
		for node: int in state.get_node_count():
			for property: int in state.get_node_property_count(node):
				_collect(state.get_node_property_value(node, property), path, by_id)
		dropped.append_array(_dropped_on_nodes(path, scene))
	var text := FileAccess.get_file_as_string(path)
	var header := RegEx.create_from_string(SECTION)
	var section_id := RegEx.create_from_string(SECTION_ID)
	var stored := RegEx.create_from_string(STORED)
	var target: Resource = null
	var where := ""
	var lines := text.split("\n")
	for number: int in lines.size():
		var line := lines[number]
		if line.begins_with("["):
			target = null
			var found := header.search(line)
			if not found:
				continue
			if found.get_string(1) == "resource":
				target = loaded
				where = "the resource"
			else:
				var id := section_id.search(found.get_string(2))
				target = by_id.get(id.get_string(1)) if id else null
				where = "sub_resource %s" % (id.get_string(1) if id else "?")
			continue
		var property := stored.search(line)
		if target and property and not _has_property(target, property.get_string(1)):
			var at := "%s:%d" % [path, number + 1]
			dropped.append(_dropped_line(at, where, property.get_string(1), target))
	return dropped


# The properties each node of [param scene] is stored with that the node doesn't have.
func _dropped_on_nodes(path: String, scene: PackedScene) -> PackedStringArray:
	var dropped := PackedStringArray()
	var state := scene.get_state()
	var root := scene.instantiate()
	if not root:
		return dropped
	for node: int in state.get_node_count():
		var instance := root.get_node_or_null(state.get_node_path(node))
		if not instance:
			continue
		var where := "node %s" % state.get_node_path(node)
		for property: int in state.get_node_property_count(node):
			var name := state.get_node_property_name(node, property)
			if not _has_property(instance, name):
				dropped.append(_dropped_line(path, where, name, instance))
	root.free()
	return dropped


# Every sub-resource of the file at [param path] reachable from [param value], by its id.
func _collect(value: Variant, path: String, by_id: Dictionary[String, Resource]) -> void:
	if value is Array:
		for item: Variant in value:
			_collect(item, path, by_id)
	elif value is Dictionary:
		for item: Variant in value:
			_collect(item, path, by_id)
			_collect(value[item], path, by_id)
	elif value is Resource:
		var resource := value as Resource
		var own := resource.resource_path.is_empty() or resource.resource_path == path
		own = own or resource.resource_path.begins_with(path + "::")
		var id := resource.resource_scene_unique_id
		if not own or (id and by_id.has(id)) or resource is PackedScene:
			return
		if id:
			by_id[id] = resource
		for property: Dictionary in resource.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE:
				_collect(resource.get(property.name), path, by_id)


func _has_property(object: Object, name: String) -> bool:
	if name.begins_with("metadata/"):
		return true
	for property: Dictionary in object.get_property_list():
		if property.name == name:
			return true
	return false


func _dropped_line(at: String, where: String, name: String, object: Object) -> String:
	var script := object.get_script() as Script
	var owner := script.resource_path if script else object.get_class()
	return (
		(
			"%s: %s stores %s, which %s doesn't have, so its value is dropped on load. "
			% [at, where, name, owner]
		)
		+ "Rename it in the file to the property's new name, or delete the line. "
		+ "(stale-property; CODING_STANDARDS.md, Static typing)"
	)
