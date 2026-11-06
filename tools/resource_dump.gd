extends SceneTree
## Prints what each scene and resource named after -- holds, one `<file> <property path> =
## <value>` line per stored property, the way the game loads it. Run through
## `uv run tools/check.py ids`, before and after tools/resave.gd, without --editor so
## every script runs as itself: the two dumps must match, or the resave lost something.

## Stored, but left out. The ids, since adding them is the point of the resave, and the
## file's own path. anchors_preset is a shortcut for the anchor_* and offset_* values,
## which are dumped: a scene root's preset reads 0 once the resave drops its
## `layout_mode = 3`, although its anchors and layout_mode load the same.
const SKIPPED: Array[String] = [
	"resource_scene_unique_id", "unique_id", "resource_path", "anchors_preset"
]


func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			print("%s <load> = failed" % path)
			continue
		var scene := resource as PackedScene
		if scene == null:
			_dump_object(path, "", resource)
			continue
		var root := scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		if root == null:
			print("%s <instantiate> = failed" % path)
			continue
		_dump_node(path, root, root)
		root.free()
	quit()


func _dump_node(file: String, root: Node, node: Node) -> void:
	var at := "/%s" % root.get_path_to(node)
	print("%s %s:<class> = %s" % [file, at, node.get_class()])
	if not node.scene_file_path.is_empty() and node != root:
		print("%s %s:<instance> = %s" % [file, at, node.scene_file_path])
	_dump_object(file, at + ":", node)
	for child: Node in node.get_children(true):
		_dump_node(file, root, child)


func _dump_object(file: String, at: String, object: Object) -> void:
	for property: Dictionary in object.get_property_list():
		var name: String = property.name
		if property.usage & PROPERTY_USAGE_STORAGE == 0 or name in SKIPPED:
			continue
		_dump_value(file, at + name, object.get(name))


func _dump_value(file: String, at: String, value: Variant) -> void:
	if value is Resource:
		var resource: Resource = value
		if resource.resource_path.is_empty() or resource.resource_path.contains("::"):
			print("%s %s = <%s>" % [file, at, resource.get_class()])
			_dump_object(file, at + "/", resource)
		else:
			print("%s %s = %s" % [file, at, resource.resource_path])
	elif value is Array:
		var array: Array = value
		print("%s %s = Array[%d]" % [file, at, array.size()])
		for index: int in array.size():
			_dump_value(file, "%s[%d]" % [at, index], array[index])
	elif value is Dictionary:
		var dictionary: Dictionary = value
		print("%s %s = Dictionary[%d]" % [file, at, dictionary.size()])
		for key: Variant in dictionary:
			_dump_value(file, "%s[%s]" % [at, var_to_str(key)], dictionary[key])
	else:
		print("%s %s = %s" % [file, at, var_to_str(value).replace("\n", "\\n")])
