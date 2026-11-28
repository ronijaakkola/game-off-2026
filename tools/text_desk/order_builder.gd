extends RefCounted
## Builds a running order for the text desk out of names: each method adds entries to the
## section under way, reading what the texts say from the game's files. running_order.gd
## is the order itself.

const Entry := preload("res://tools/text_desk/desk_entry.gd")
const Store := preload("res://tools/text_desk/text_store.gd")

const REST := "Everything else"
## Folders the game's text is in, and what in them is for the team, not the player.
const FOLDERS: Array[String] = ["res://ui", "res://core", "res://shared", "res://game"]
const NOT_PLAYER: Array[String] = [
	"res://ui/mixer/",
	"res://core/dev_console/",
	"res://core/debug_panel/",
	"res://core/fps_counter/",
	"res://core/online/",
	"res://game/transmissions/voice",
	"res://game/solar_system/debug_buttons.gd",
]
## A scene's or a resource's properties that hold text for the player.
const TEXT_PROPERTIES: Array[String] = [
	"text",
	"title",
	"sentence",
	"tagline",
	"lore",
	"description",
	"placeholder_text",
	"display_name",
	"roles",
	"line",
	"waiting_line",
	"item",
	"request_line",
	"serve_label",
	"served_line",
	"arrival_call",
	"promotion_call",
	"mechanic_call",
]  # gdlint: ignore

const HINTS := "res://game/feature_hints/feature_hints.gd"
const SYSTEMS := "res://game/solar_system/systems/%s.tscn"


## One section of the running order.
class Section:
	var title := ""
	var entries: Array[Entry] = []


var _store: Store
var _sections: Array[Section] = []
# The texts an entry shows, as "path::key", so the rest are the ones left over.
var _named: Dictionary[String, Entry.Text] = {}


func _init(store: Store) -> void:
	_store = store


## Every text in the game's folders no entry shows that looks written for the player.
func add_rest() -> void:
	section(REST)
	for folder: String in FOLDERS:
		for path: String in _files_in(folder):
			for key: String in _store.get_keys(path):
				if not _named.has("%s::%s" % [path, key]) and _is_player_text(path, key):
					var where := "%s  %s" % [path.get_file(), key.get_slice(":", 1).get_file()]
					one(where, "label", {text = [path, key]})


## Every text an entry shows, each once.
func get_texts() -> Array[Entry.Text]:
	var texts: Array[Entry.Text] = []
	texts.assign(_named.values())
	return texts


func section(title: String) -> void:
	var section := Section.new()
	section.title = title
	_sections.append(section)


## An entry showing on [param stage], whose [param roles] each name a text as
## [code][path, key][/code].
func one(title: String, stage: String, roles: Dictionary, options := {}) -> Entry:
	var entry := Entry.new()
	entry.title = title
	entry.stage = stage
	entry.options = options
	for role: String in roles:
		var where: Array = roles[role]
		entry.fields.append(_field(role, where[0], where[1]))
	_sections[-1].entries.append(entry)
	return entry


func _field(role: String, path: String, key: String) -> Entry.Field:
	var name := "%s::%s" % [path, key]
	if not _named.has(name):
		var text := Entry.Text.new()
		text.path = path
		text.key = key
		text.missing = not _store.has(path, key)
		text.saved = _store.read(path, key)
		text.value = text.saved
		_named[name] = text
	var field := Entry.Field.new()
	field.role = role
	field.text = _named[name]
	return field


## An entry for each text in [param path] whose key starts with [param prefix], in the
## order they are written. A scene or a resource gives only its properties that hold text.
func all(path: String, prefix: String, stage: String, options := {}) -> void:
	var role: String = options.get("role", "title" if stage == "tooltip" else "text")
	for key: String in keys(path, prefix):
		var value := _store.read(path, key)
		var title := value.left(40) if value.strip_edges() != "" else key
		one(title, stage, {role: [path, key]}, options)


## An entry for each group of texts in [param path] under [param prefix] that share all
## but the last part of their key, as a card's title and text: the last part is the role,
## a description being the text.
func groups(path: String, prefix: String, stage: String, options := {}, label := "") -> void:
	var groups: Dictionary[String, Dictionary] = {}
	for key: String in keys(path, prefix):
		var role := key.get_file()
		groups.get_or_add(key.get_base_dir(), {})["text" if role == "description" else role] = [
			path, key
		]
	for group: String in groups:
		var roles := groups[group]
		var named: Array = roles.get("title", roles.values()[0])
		var title := _store.read(named[0], named[1]).left(40)
		one(label + (title if roles.has("title") else group.get_file()), stage, roles, options)


## A call from [param who]: [param texts] one after another, with the two answers of
## [param answers], which mean the same.
func call_from(
	title: String,
	path: String,
	who: String,
	caller: String,
	texts: Array[String],
	answers: String,
	options := {}
) -> void:
	var entry := one(title, "transmission", {}, options.merged({caller = who, alike = true}))
	if caller != "":
		entry.fields.append(_field("caller", path, caller))
	for i: int in texts.size():
		entry.fields.append(_field("opening" if i < texts.size() - 1 else "text", path, texts[i]))
	entry.fields.append(_field("decline", path, answers + "/0"))
	entry.fields.append(_field("accept", path, answers + "/1"))


func hint(hint: String) -> void:
	var roles := {title = [HINTS, "HINTS/%s/title" % hint], text = [HINTS, "HINTS/%s/text" % hint]}
	one("Hint: %s" % hint.capitalize(), "guide", roles, {hint = true})


func tooltip(title: String, path: String, node: String) -> void:
	var roles := {}
	if _store.has(path, node + "/title"):
		roles.title = [path, node + "/title"]
	if _store.has(path, node + "/sentence"):
		roles.text = [path, node + "/sentence"]
	one("Tooltip: %s" % title, "tooltip", roles)


# The planets of [param system], each its tagline and lore as the planet panel shows them.
func planets(system: String) -> void:
	var path := SYSTEMS % system
	for key: String in keys(path, "node:"):
		if key.get_file() == "tagline":
			var planet := key.get_base_dir()
			var roles := {title = [path, key], text = [path, planet + "/lore"]}
			one("Planet: %s" % planet.trim_prefix("node:"), "label", roles, {width = 232})


# The keys in [param path] that start with [param prefix] and hold text for the player.
func keys(path: String, prefix: String) -> PackedStringArray:
	var keys := PackedStringArray()
	for key: String in _store.get_keys(path):
		var is_text := path.get_extension() == "gd" or key.get_file() in TEXT_PROPERTIES
		if key.begins_with(prefix) and is_text and _store.read(path, key).strip_edges() != "":
			keys.append(key)
	return keys


func _is_player_text(path: String, key: String) -> bool:
	var value := _store.read(path, key)
	if path.get_extension() != "gd":
		return key.get_file() in TEXT_PROPERTIES and value.strip_edges().length() > 1
	var first := value.left(1)
	var worded := value.contains(" ") and first == first.to_upper() and first != first.to_lower()
	var for_team := key.contains("DEBUG") or key.begins_with("_ready") or key.contains("debug")
	return worded and not for_team and not value.contains("res://") and not value.contains(": %s")


func _files_in(folder: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub: String in DirAccess.get_directories_at(folder):
		files.append_array(_files_in("%s/%s" % [folder, sub]))
	for file: String in DirAccess.get_files_at(folder):
		var path := "%s/%s" % [folder, file]
		var is_team := NOT_PLAYER.any(func(prefix: String) -> bool: return path.begins_with(prefix))
		if file.get_extension() in ["gd", "tscn", "tres"] and not is_team:
			files.append(path)
	return files
