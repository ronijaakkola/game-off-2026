extends CanvasLayer
## The debug panel: buttons for testing, in the bottom left corner, opened and closed
## with F2. It starts closed and works while the game is paused. A scene adds its own
## buttons with [method add_button], and they go when the scene does, so the panel never
## needs to know which scene is running. Buttons given a group go on that group's own
## card to the right of the main one, which a button of the group's name in the main card
## opens and closes. One group's card shows at a time.
## It ships in every build, release builds included, until [constant ENABLED] is set to
## false before the game is released.

## Whether the panel exists. Set to false before the game is released: F2 then does
## nothing and [method add_button] adds nothing.
const ENABLED := true
## Opens and closes the panel. A physical key, so it is the same on every keyboard layout.
const TOGGLE_KEY := KEY_F2
## How wide each card is at least.
const CARD_WIDTH := 180.0

# Each group's card, the column of buttons on it, and the button in the main card that
# opens it, by the group's name.
var _group_cards: Dictionary[String, Control] = {}
var _group_buttons: Dictionary[String, Container] = {}
var _group_toggles: Dictionary[String, Button] = {}
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
## and the button that opens it go with the group's last button.
func add_button(text: String, action: Callable, scene: Node, group := "") -> void:
	if not ENABLED:
		return
	var button := _make_button(text)
	button.pressed.connect(action)
	button.tree_exited.connect(_tidy, CONNECT_DEFERRED)
	scene.tree_exiting.connect(button.queue_free)
	_buttons_for(group).add_child(button)
	_tidy()


## Whether [param group]'s card shows.
func is_group_open(group: String) -> bool:
	return _group_cards.has(group) and _group_cards[group].visible


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
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
	toggle.toggle_mode = true
	toggle.button_group = _toggles
	toggle.toggled.connect(card.set_visible)
	(%Buttons as Container).add_child(toggle)
	_group_cards[group] = card
	_group_buttons[group] = buttons
	_group_toggles[group] = toggle


# Takes out each group with no buttons left, and shows a line saying so when the running
# scene adds no buttons.
func _tidy() -> void:
	for group: String in _group_buttons.keys():
		if _group_buttons[group].get_child_count() > 0:
			continue
		for node: Node in [_group_cards[group], _group_toggles[group]]:
			node.get_parent().remove_child(node)
			node.queue_free()
		_group_cards.erase(group)
		_group_buttons.erase(group)
		_group_toggles.erase(group)
	(%EmptyLabel as Control).visible = (%Buttons as Container).get_child_count() == 0
