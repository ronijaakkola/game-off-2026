extends RefCounted
## Finds the text a scene or a resource holds, and writes a text back as Godot saves it:
## the text desk's reader and writer for [code].tscn[/code] and [code].tres[/code] files.
## A text is a property whose whole value is a string. Its key is the section it is in and
## the property's name: [code]node:Card/Title/text[/code] for a node by its path
## ([code]node:./text[/code] for the root), [code]sub:Resource_abc12/title[/code] for a
## sub-resource by its id, and [code]resource/title[/code] for a resource's own.

const Found := preload("res://tools/text_desk/found_text.gd")

const SECTION := "^\\[(\\w+)([^\\n]*)\\]$"
const PROPERTY := '^([A-Za-z_][\\w/]*) = "'
const ATTRIBUTE := '\\b%s="([^"]*)"'

static var _section := RegEx.create_from_string(SECTION)
static var _property := RegEx.create_from_string(PROPERTY)
static var _name := RegEx.create_from_string(ATTRIBUTE % "name")
static var _parent := RegEx.create_from_string(ATTRIBUTE % "parent")
static var _id := RegEx.create_from_string(ATTRIBUTE % "id")


## Every text in [param source], in the order they are written.
static func scan(source: String) -> Array[Found]:
	var found: Array[Found] = []
	var section := ""
	var at := 0
	while at < source.length():
		var line_end := source.find("\n", at)
		if line_end < 0:
			line_end = source.length()
		var line := source.substr(at, line_end - at)
		var header := _section.search(line)
		var property := _property.search(line)
		if header:
			section = _section_key(header.get_string(1), header.get_string(2))
		elif property and section != "":
			var open := at + property.get_end() - 1
			var literal := _read_literal(source, open)
			var end: int = literal.end
			line_end = source.find("\n", end)
			if line_end < 0:
				line_end = source.length()
			# Only a value that is the string and nothing after it.
			if source.substr(end, line_end - end).strip_edges() == "":
				var text := Found.new()
				text.key = "%s/%s" % [section, property.get_string(1)]
				text.value = literal.value
				text.start = open
				text.end = end
				found.append(text)
		at = line_end + 1
	return found


## [param value] as Godot saves a string: only the backslash and the quote escaped, a new
## line as it is.
static func write_literal(value: String) -> String:
	return '"%s"' % value.replace("\\", "\\\\").replace('"', '\\"')


# The key of a section, or empty for one that holds no text of its own.
static func _section_key(kind: String, attributes: String) -> String:
	if kind == "resource":
		return "resource"
	if kind == "sub_resource":
		var id := _id.search(attributes)
		return "sub:%s" % id.get_string(1) if id else ""
	if kind != "node":
		return ""
	var name := _name.search(attributes)
	var parent := _parent.search(attributes)
	if not name:
		return ""
	if not parent:
		return "node:."
	if parent.get_string(1) == ".":
		return "node:%s" % name.get_string(1)
	return "node:%s/%s" % [parent.get_string(1), name.get_string(1)]


# The string that opens at [param at]: what it says and where it ends.
static func _read_literal(source: String, at: int) -> Dictionary:
	var i := at + 1
	var value := ""
	while i < source.length():
		if source[i] == "\\" and i + 1 < source.length():
			var escaped := source[i + 1]
			value += {"n": "\n", "t": "\t"}.get(escaped, escaped)
			i += 2
		elif source[i] == '"':
			return {value = value, end = i + 1}
		else:
			value += source[i]
			i += 1
	return {value = value, end = source.length()}
