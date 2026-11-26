extends CanvasLayer
## The debug panel: buttons for testing, in the bottom left corner, opened and closed
## with F2. It starts closed and works while the game is paused. A scene adds its own
## buttons with [method add_button], and they go when the scene does, so the panel never
## needs to know which scene is running. The main card lays them out in two columns, in the
## order added, row by row, every button as wide as the widest. Buttons given a group go on
## that group's own card to the right of the main one, which a button of the group's name in
## the main card opens and closes, its name on the left and a faint › at its right edge.
## Those buttons sit together under Sections, below the ones that act at once. One group's
## card shows at a time.
## It ships in every build, release builds included, until [constant ENABLED] is set to
## false before the game is released.

## Whether the panel exists. Set to false before the game is released: F2 then does
## nothing and [method add_button] adds nothing.
const ENABLED := true
## Opens and closes the panel. A physical key, so it is the same on every keyboard layout.
const TOGGLE_KEY := KEY_F2
## How wide each card is at least.
const CARD_WIDTH := 180.0
## At the right edge of each button that opens a group's card: a character, not an icon, so
## it sits on the name's baseline.
const SECTION_MARK := "›"
## How opaque the mark is: fainter than the name.
const MARK_ALPHA := 0.55
## The least room between a toggle's name and its mark.
const MARK_GAP := 8.0

# Each group's card, the column of buttons on it, and the button in the main card that
# opens it, by the group's name.
var _group_cards: Dictionary[String, Control] = {}
var _group_buttons: Dictionary[String, Container] = {}
var _group_toggles: Dictionary[String, Button] = {}
# The › on each group's toggle, by the toggle.
var _marks: Dictionary[Button, Label] = {}
# Groups the toggles, so opening one group's card closes the others'.
var _toggles := ButtonGroup.new()


func _ready() -> void:
	(%Root as Control).hide()
	_toggles.allow_unpress = true
	_tidy()


func _input(event: InputEvent) -> void:
	if not ENABLED:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		var root := %Root as Control
		root.visible = not root.visible
		get_viewport().set_input_as_handled()


## Whether the panel is open.
func is_open() -> bool:
	return (%Root as Control).visible


## Adds a button labelled [param text] that calls [param action] when pressed. It stays
## while [param scene] is in the tree, so a scene's buttons go when the scene does. With
## a [param group], it goes on that group's card instead of the main one; a group's card
## and the button that opens it go with the group's last button. Returns the button, so the
## scene can disable it while it would do nothing, or null with the panel off.
func add_button(text: String, action: Callable, scene: Node, group := "") -> Button:
	if not ENABLED:
		return null
	var button := _make_button(text)
	button.pressed.connect(action)
	button.tree_exited.connect(_tidy, CONNECT_DEFERRED)
	scene.tree_exiting.connect(button.queue_free)
	_buttons_for(group).add_child(button)
	_tidy()
	return button


## Whether [param group]'s card shows.
func is_group_open(group: String) -> bool:
	return _group_cards.has(group) and _group_cards[group].visible


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
	# The main card's two columns share its width evenly ([method _even_widths]).
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# So keys the game uses, such as Space, never press it.
	button.focus_mode = Control.FOCUS_NONE
	return button


func _buttons_for(group: String) -> Container:
	if group.is_empty():
		return %Buttons as Container
	if not _group_buttons.has(group):
		_add_group(group)
	return _group_buttons[group]


# A card for group to the right of the others, shut, and a toggle in the main card that
# opens it.
func _add_group(group: String) -> void:
	var card := PanelContainer.new()
	card.name = "%sCard" % group.to_pascal_case()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size.x = CARD_WIDTH
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	card.hide()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 6)
	card.add_child(rows)
	var title := Label.new()
	title.text = group
	title.theme_type_variation = &"SmallLabel"
	rows.add_child(title)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 4)
	rows.add_child(buttons)
	(%Cards as Container).add_child(card)
	var toggle := _make_button(group)
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode = true
	toggle.button_group = _toggles
	toggle.toggled.connect(card.set_visible)
	(%Groups as Container).add_child(toggle)
	_add_mark(toggle)
	_group_cards[group] = card
	_group_buttons[group] = buttons
	_group_toggles[group] = toggle


# The faint › at the right edge of a group's toggle, in the toggle's own font, so it sits on
# the name's baseline. Toggle is in the tree, so its theme is known.
func _add_mark(toggle: Button) -> void:
	var mark := Label.new()
	mark.text = SECTION_MARK
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override(&"font", toggle.get_theme_font(&"font"))
	mark.add_theme_font_size_override(&"font_size", toggle.get_theme_font_size(&"font_size"))
	mark.add_theme_color_override(&"font_color", toggle.get_theme_color(&"font_color"))
	mark.modulate.a = MARK_ALPHA
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.offset_right = -toggle.get_theme_stylebox(&"normal").content_margin_right
	toggle.add_child(mark)
	_marks[toggle] = mark


# Every button in the main card as wide as the widest, a toggle's mark counted, so the
# columns of the buttons and of Sections line up.
func _even_widths() -> void:
	var all: Array[Node] = (%Buttons as Node).get_children() + (%Groups as Node).get_children()
	var widest := 0.0
	for button: Button in all:
		button.custom_minimum_size.x = 0.0
		var width := button.get_combined_minimum_size().x
		if _marks.has(button):
			width += _marks[button].get_minimum_size().x + MARK_GAP
		widest = maxf(widest, width)
	for button: Button in all:
		button.custom_minimum_size.x = widest


# Takes out each group with no buttons left, shows Sections only with a group in it, and
# shows a line saying so when the running scene adds no buttons.
func _tidy() -> void:
	for group: String in _group_buttons.keys():
		if _group_buttons[group].get_child_count() > 0:
			continue
		for node: Node in [_group_cards[group], _group_toggles[group]]:
			node.get_parent().remove_child(node)
			node.queue_free()
		_marks.erase(_group_toggles[group])
		_group_cards.erase(group)
		_group_buttons.erase(group)
		_group_toggles.erase(group)
	var has_groups := (%Groups as Container).get_child_count() > 0
	(%GroupsLabel as Control).visible = has_groups
	(%Groups as Control).visible = has_groups
	var has_buttons := (%Buttons as Container).get_child_count() > 0
	(%Buttons as Control).visible = has_buttons
	(%EmptyLabel as Control).visible = not has_buttons and not has_groups
	_even_widths()
