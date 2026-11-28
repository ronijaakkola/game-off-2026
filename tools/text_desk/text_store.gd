extends RefCounted
## The game's text as its files hold it: reads the texts of a script, a scene or a
## resource by key ([code]gd_strings.gd[/code], [code]scene_strings.gd[/code]), and writes
## changed ones back into the same files, each where it was. Nothing else in a file
## changes, and a text that is no longer what the desk read isn't written over.

const GdStrings := preload("res://tools/text_desk/gd_strings.gd")
const SceneStrings := preload("res://tools/text_desk/scene_strings.gd")
const Found := preload("res://tools/text_desk/found_text.gd")

const CHECK := "res://tools/check.py"

## Whether a save has gdformat lay the scripts out. Off for a file outside the project,
## as in a test.
var formats := true

# Each file read so far: its texts by key, in the order they are written.
var _files: Dictionary[String, Dictionary] = {}


## The keys of the texts in [param path], in the order they are written.
func get_keys(path: String) -> PackedStringArray:
	return PackedStringArray(_read(path).keys())


func has(path: String, key: String) -> bool:
	return _read(path).has(key)


## What the text at [param key] in [param path] says, or empty when there is none.
func read(path: String, key: String) -> String:
	var found: Found = _read(path).get(key)
	return found.value if found else ""


## Writes each of [param changes], a [code]{path, key, old, new}[/code], into its file,
## then has gdformat lay the scripts out. Returns what went wrong, a line each: a text that
## has moved or changed since it was read is left as it is.
func save(changes: Array[Dictionary]) -> PackedStringArray:
	var problems := PackedStringArray()
	var by_path: Dictionary[String, Array] = {}
	for change: Dictionary in changes:
		by_path.get_or_add(change.path, []).append(change)
	var scripts := PackedStringArray()
	for path: String in by_path:
		_files.erase(path)
		var source := FileAccess.get_file_as_string(path)
		var texts := _read(path)
		var edits: Array[Dictionary] = []
		for change: Dictionary in by_path[path]:
			var found: Found = texts.get(change.key)
			if not found:
				problems.append("%s: no text at %s any more" % [path, change.key])
			elif found.value != change.old:
				problems.append("%s: %s changed in the file since it was read" % [path, change.key])
			else:
				edits.append({found = found, value = change.new})
		if edits.is_empty():
			continue
		# From the end, so the spans before an edit stay where they were found.
		edits.sort_custom(_is_later)
		for edit: Dictionary in edits:
			var found: Found = edit.found
			var literal := _write_literal(path, source, found.start, edit.value)
			source = source.substr(0, found.start) + literal + source.substr(found.end)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			problems.append(
				"%s: can't write (%s)" % [path, error_string(FileAccess.get_open_error())]
			)
			continue
		file.store_string(source)
		file.close()
		_files.erase(path)
		if path.get_extension() == "gd":
			scripts.append(path.trim_prefix("res://"))
	if formats and not scripts.is_empty() and not _format(scripts):
		problems.append("gdformat didn't run. Run: uv run tools/check.py format")
	for path: String in by_path:
		_files.erase(path)
	return problems


# The texts of [param path] by key, read once.
func _read(path: String) -> Dictionary:
	if not _files.has(path):
		var source := FileAccess.get_file_as_string(path)
		var is_script := path.get_extension() == "gd"
		var texts := {}
		for found: Found in GdStrings.scan(source) if is_script else SceneStrings.scan(source):
			texts[found.key] = found
		_files[path] = texts
	return _files[path]


func _is_later(a: Dictionary, b: Dictionary) -> bool:
	return a.found.start > b.found.start


func _write_literal(path: String, source: String, at: int, value: String) -> String:
	if path.get_extension() != "gd":
		return SceneStrings.write_literal(value)
	return GdStrings.write_literal(
		value, GdStrings.get_indent(source, at), GdStrings.get_column(source, at)
	)


# Lays [param scripts] out with gdformat, through check.py. Whether it ran.
func _format(scripts: PackedStringArray) -> bool:
	var arguments := PackedStringArray(["run", ProjectSettings.globalize_path(CHECK), "format"])
	arguments.append_array(scripts)
	return OS.execute("uv", arguments) == 0
