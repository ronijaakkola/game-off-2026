extends CanvasLayer
## The text desk: every text the player reads, in the order a run meets them
## (running_order.gd), each shown in the running game with the widget it has there
## (stages.gd), to edit in place and save back into the file that holds it
## (text_store.gd). Run the scene from the editor with F6; it is in tools/, which no build
## exports.
## The panel on the right lists the texts. Picking one shows it in the game and opens its
## parts to edit; the game follows as you type, and the line under them says how the text
## fits its widget. The buttons over that line wrap the selection in a text effect, or put
## in a control's icon, whichever the widget shows. Save writes every changed text into
## its script, scene or resource and has gdformat lay the scripts out; nothing is written
## before that. Copy all puts the whole running order on the clipboard as Markdown, to
## read or spell-check elsewhere.
## Ctrl+S saves, Alt+Down and Alt+Up go to the next and the last text, and F1 hides the
## panel to see the whole screen. `-- entry <n>` opens on the nth text, `-- dock_left` docks
## the panel on the left, and `-- find <words>` filters the list, for a capture.

const Entry := preload("res://tools/text_desk/desk_entry.gd")
const Store := preload("res://tools/text_desk/text_store.gd")
const Order := preload("res://tools/text_desk/running_order.gd")
const Stages := preload("res://tools/text_desk/stages.gd")

const THEME := preload("res://ui/theme.tres")
## The panel's width, in pixels: what is left beside a transmission's modal.
const WIDTH := 292.0
const BACKGROUND := Color(0.07, 0.06, 0.16)
const DIM := Color(0.957, 0.945, 1.0, 0.6)
const CHANGED := Color(0.96, 0.78, 0.29)
const OVER := Color(0.949, 0.302, 0.4)
## Seconds after the last key before the game shows the text.
const TYPING_PAUSE := 0.15
## What wraps the selection in a call's words: the game's own effects, then Godot's.
const EFFECTS: Array[Array] = [
	["money", "[money]", "[/money]"],
	["shout", "[shout]", "[/shout]"],
	["wave", "[wave amp=20 freq=5]", "[/wave]"],
	["shake", "[shake rate=20 level=5]", "[/shake]"],
	["tornado", "[tornado radius=3 freq=4]", "[/tornado]"],
	["rainbow", "[rainbow]", "[/rainbow]"],
	["pulse", "[pulse]", "[/pulse]"],
	["fade", "[fade start=0 length=12]", "[/fade]"],
	["colour", "[color=#f5c84a]", "[/color]"],
]

## How white a panel button is in each state, from 0 to 1.
const BUTTON_FILLS: Dictionary[StringName, float] = {
	&"normal": 0.1,
	&"hover": 0.18,
	&"pressed": 0.26,
	&"disabled": 0.04,
}

## The running solar system the texts show in.
@export var solar: Node

var _store := Store.new()
var _order: Order
var _sections: Array[Order.Section] = []
var _stages: Stages
# The entries the list shows, in order, and the one open.
var _listed: Array[Entry] = []
var _entry: Entry
var _items: Dictionary[Entry, TreeItem] = {}
var _panel: PanelContainer
var _tree: Tree
var _filter: LineEdit
var _heading: Label
var _fields: VBoxContainer
var _tools: HFlowContainer
var _fit: Label
var _status: Label
var _save: Button
var _editing: TextEdit
var _typing: Timer
var _on_left := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_order = Order.new(_store)
	_sections = _order.build()
	_stages = Stages.new()
	_stages.solar = solar
	add_child(_stages)
	# The keys typed here would steer the camera and the route.
	(solar.get_node(^"CameraRig") as CameraRig).locked = true
	(solar.get_node(^"Bus") as FrameshiftBus).route_locked = true
	_typing = Timer.new()
	_typing.one_shot = true
	_typing.wait_time = TYPING_PAUSE
	_typing.timeout.connect(_show)
	add_child(_typing)
	_build()
	var arguments := OS.get_cmdline_user_args()
	if "dock_left" in arguments:
		_dock(true)
	if "find" in arguments:
		_filter.text = " ".join(arguments.slice(arguments.find("find") + 1))
	_list()
	# Once the HUD is in, so the first text has something to show on.
	await get_tree().create_timer(0.5).timeout
	var first := int(arguments[arguments.find("entry") + 1]) if "entry" in arguments else 0
	if first < _listed.size():
		_open(_listed[first])


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.keycode == KEY_S and key.is_command_or_control_pressed():
		_save_all()
	elif key.keycode == KEY_F1:
		_panel.visible = not _panel.visible
	elif key.keycode == KEY_DOWN and key.alt_pressed:
		_step(1)
	elif key.keycode == KEY_UP and key.alt_pressed:
		_step(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = THEME
	var box := StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)
	_dock(false)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 6)
	_panel.add_child(rows)
	var top := HBoxContainer.new()
	rows.add_child(top)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Find a text"
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(_list.unbind(1))
	top.add_child(_filter)
	top.add_child(_button("Side", func() -> void: _dock(not _on_left)))
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_stretch_ratio = 1.2
	_tree.add_theme_font_size_override(&"font_size", 12)
	_tree.item_selected.connect(_on_item_selected)
	rows.add_child(_tree)
	_heading = _label("", false)
	rows.add_child(_heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	_tools = HFlowContainer.new()
	rows.add_child(_tools)
	_fit = _label("", false)
	rows.add_child(_fit)
	var steps := HBoxContainer.new()
	rows.add_child(steps)
	steps.add_child(_button("Last", _step.bind(-1)))
	steps.add_child(_button("Next", _step.bind(1)))
	steps.add_child(_button("Replay", _replay))
	steps.add_child(_button("Revert", _revert))
	var ends := HBoxContainer.new()
	rows.add_child(ends)
	_save = _button("Save", _save_all)
	_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(_save)
	ends.add_child(_button("Copy all", _copy_all))
	_status = _label("", false)
	_status.add_theme_color_override(&"font_color", DIM)
	rows.add_child(_status)


# Fills the list with the entries the filter keeps, under their sections.
func _list() -> void:
	_tree.clear()
	_items.clear()
	_listed.clear()
	var root := _tree.create_item()
	var words := _filter.text.to_lower()
	for section: Order.Section in _sections:
		var kept := section.entries.filter(_matches.bind(words))
		if kept.is_empty():
			continue
		var heading := _tree.create_item(root)
		heading.set_text(0, "%s (%d)" % [section.title, kept.size()])
		heading.set_selectable(0, false)
		heading.set_custom_color(0, DIM)
		heading.collapsed = words == "" and section.title == Order.REST
		for entry: Entry in kept:
			var item := _tree.create_item(heading)
			item.set_metadata(0, entry)
			_items[entry] = item
			_listed.append(entry)
			_mark(entry)
	_count()


func _matches(entry: Entry, words: String) -> bool:
	if words == "" or entry.title.to_lower().contains(words):
		return true
	return entry.fields.any(
		func(field: Entry.Field) -> bool: return field.text.value.to_lower().contains(words)
	)


# Shows in the list whether [param entry] has changes, or names a text that is gone.
func _mark(entry: Entry) -> void:
	var item: TreeItem = _items.get(entry)
	if not item:
		return
	var missing := entry.fields.any(func(field: Entry.Field) -> bool: return field.text.missing)
	item.set_text(0, ("* " if entry.is_changed() else "") + entry.title)
	if missing:
		item.set_custom_color(0, OVER)
	elif entry.is_changed():
		item.set_custom_color(0, CHANGED)
	else:
		item.clear_custom_color(0)


func _on_item_selected() -> void:
	var entry: Entry = _tree.get_selected().get_metadata(0)
	if entry and entry != _entry:
		_open(entry)


# Opens [param entry]: its parts to edit, the effects its widget shows, and the game
# showing it.
func _open(entry: Entry) -> void:
	_entry = entry
	_editing = null
	var item: TreeItem = _items.get(entry)
	if item and _tree.get_selected() != item:
		item.select(0)
		_tree.scroll_to_item(item)
	_heading.text = "%s  ·  %s" % [entry.title, entry.stage]
	for child: Node in _fields.get_children():
		child.queue_free()
	for field: Entry.Field in entry.fields:
		var text := field.text
		var where := _label("%s  ·  %s  %s" % [field.role, text.path.get_file(), text.key], true)
		where.tooltip_text = "%s\n%s" % [text.path, text.key]
		_fields.add_child(where)
		if text.missing:
			where.add_theme_color_override(&"font_color", OVER)
			where.text += "  (not found: fix running_order.gd)"
			continue
		var edit := TextEdit.new()
		edit.text = text.value
		edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		edit.scroll_fit_content_height = true
		edit.custom_minimum_size.y = 30.0
		edit.add_theme_font_size_override(&"font_size", 12)
		edit.focus_entered.connect(func() -> void: _editing = edit)
		edit.text_changed.connect(_on_edited.bind(edit, text))
		_fields.add_child(edit)
		if not _editing:
			_editing = edit
	_show_tools()
	_show()


func _show_tools() -> void:
	for child: Node in _tools.get_children():
		child.queue_free()
	if _entry.stage == "transmission":
		for effect: Array in EFFECTS:
			_tools.add_child(_button(effect[0], _wrap.bind(effect[1], effect[2])))
	elif _entry.stage == "guide":
		for icon: String in ControlIcons.ICONS:
			_tools.add_child(_button(icon, _wrap.bind("{%s}" % icon, "")))


func _on_edited(edit: TextEdit, text: Entry.Text) -> void:
	text.value = edit.text
	# Every entry that shows this text.
	for entry: Entry in _items:
		if entry.fields.any(func(field: Entry.Field) -> bool: return field.text == text):
			_mark(entry)
	_count()
	_typing.start()


# Shows the open entry in the game and, once its widget has laid it out, how it fits.
func _show(replay := false) -> void:
	if not _entry:
		return
	var entry := _entry
	_stages.show_entry(entry, replay)
	for i: int in 3:
		await get_tree().process_frame
	if entry != _entry:
		return
	var fit := _stages.describe(entry)
	_fit.text = fit.text
	_fit.add_theme_color_override(&"font_color", OVER if fit.over else DIM)


func _replay() -> void:
	_show(true)


# Puts [param before] and [param after] round the selection in the part being edited, or
# at the caret with nothing selected.
func _wrap(before: String, after: String) -> void:
	if not is_instance_valid(_editing):
		return
	var selected := _editing.get_selected_text()
	if _editing.has_selection():
		_editing.delete_selection()
	_editing.insert_text_at_caret(before + selected + after)
	_editing.grab_focus()


func _revert() -> void:
	if not _entry:
		return
	for field: Entry.Field in _entry.fields:
		field.text.value = field.text.saved
	_list()
	_open(_entry)


func _step(by: int) -> void:
	if _listed.is_empty():
		return
	var at := _listed.find(_entry)
	_open(_listed[clampi(at + by, 0, _listed.size() - 1)])


func _changed() -> Array[Entry.Text]:
	var changed: Array[Entry.Text] = []
	for text: Entry.Text in _order.get_texts():
		if text.is_changed():
			changed.append(text)
	return changed


func _count() -> void:
	var count := _changed().size()
	_save.text = "Save" if count == 0 else "Save %d" % count
	_save.disabled = count == 0


# Writes every changed text into its file.
func _save_all() -> void:
	var changed := _changed()
	if changed.is_empty():
		return
	var changes: Array[Dictionary] = []
	var paths: Dictionary[String, bool] = {}
	for text: Entry.Text in changed:
		changes.append({path = text.path, key = text.key, old = text.saved, new = text.value})
		paths[text.path] = true
	_status.text = "Saving…"
	await get_tree().process_frame
	var problems := _store.save(changes)
	for text: Entry.Text in changed:
		# What the file says now: a text that wasn't written stays changed.
		text.saved = _store.read(text.path, text.key)
	for entry: Entry in _items:
		_mark(entry)
	_count()
	if problems.is_empty():
		_status.text = "Saved %d texts in %d files." % [changed.size(), paths.size()]
	else:
		_status.text = "\n".join(problems)


# The whole running order on the clipboard, as Markdown.
func _copy_all() -> void:
	var lines := PackedStringArray()
	for section: Order.Section in _sections:
		lines.append("## %s\n" % section.title)
		for entry: Entry in section.entries:
			lines.append("### %s (%s)\n" % [entry.title, entry.stage])
			for field: Entry.Field in entry.fields:
				lines.append("- %s: %s" % [field.role, field.text.value.c_escape()])
			lines.append("")
	DisplayServer.clipboard_set("\n".join(lines))
	_status.text = "Copied the running order as Markdown."


# Docks the panel at the right edge of the screen, or the left.
func _dock(left: bool) -> void:
	_on_left = left
	_panel.anchor_left = 0.0 if left else 1.0
	_panel.anchor_right = _panel.anchor_left
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 0.0 if left else -WIDTH
	_panel.offset_right = WIDTH if left else 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# So a press leaves the caret and the selection where they are.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 11)
	for state: StringName in BUTTON_FILLS:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 1.0, 1.0, BUTTON_FILLS[state])
		box.set_corner_radius_all(5)
		box.set_content_margin_all(3.0)
		box.content_margin_left = 7.0
		box.content_margin_right = 7.0
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	return button


# A line of the panel's own: [param small] for one that says where something is, cut
# short with an ellipsis rather than wrapped.
func _label(text: String, small: bool) -> Label:
	var label := Label.new()
	label.text = text
	if small:
		label.add_theme_color_override(&"font_color", DIM)
		label.add_theme_font_size_override(&"font_size", 10)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		label.add_theme_font_size_override(&"font_size", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
