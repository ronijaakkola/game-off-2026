extends SceneTree
## Converts the editor's class reference cache to JSON for `check.py api`.
## Arguments after `--`: the editor_doc_cache .res file, then the .json file to write.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cache: Resource = load(args[0])
	var classes: Array = cache.get_meta(&"classes", []) if cache else []
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if classes.is_empty() or not file:
		printerr("api_dump: no classes in %s" % args[0])
		quit(1)
		return
	file.store_string(JSON.stringify(classes))
	file.close()
	print("api_dump: %d classes" % classes.size())
	quit()
