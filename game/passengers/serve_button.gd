class_name ServeButton
extends Button
## A passenger card's button to hold down to serve their request, as the fuel button is
## held to refuel: a faint fill sweeps across it as the request is served, by hand or by
## an amenity, so it fills by itself while one serves them. The card sets
## [member progress] and what it says with [method show_request], and relays
## [signal hold_changed] to whoever serves. The need's icon and label sit centred together;
## the button's own text and icon stay empty.

## The player pressed it down, with [param held] true, or let go, or it hid or turned off
## while held, with [param held] false.
signal hold_changed(held: bool)
## PROTOTYPE: a move in the minigame tried in the hold's place served [param amount] more
## of the request ([ServeMinigamePrototype]).
signal fed(amount: float)

## The fill's colour: the fuel's cyan, faint, so the label stays readable over it.
const FILL_COLOR := Color(0.6, 0.949, 1.0, 0.35)
## The icon's size, and the gap between it and the label, in pixels.
const ICON_SIZE := 10.0
const ICON_GAP := 4

## How much of the request is served, from 0 to 1: the fill's share of the width.
var progress := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if value != progress:
			progress = value
			queue_redraw()
		if _game:
			_game.progress = progress

var _held := false
# The need's icon and label, centred together. Made in _ready().
var _icon: TextureRect
var _label: Label
var _row: HBoxContainer
# PROTOTYPE: the minigame tried in the hold's place, drawn over the button.
var _game: ServeMinigamePrototype
# The fill's style: a flat box with the button's corners.
var _fill_style := StyleBoxFlat.new()


func _ready() -> void:
	_fill_style.bg_color = FILL_COLOR
	var button_style := get_theme_stylebox(&"normal") as StyleBoxFlat
	if button_style:
		for corner: int in 4:
			_fill_style.set_corner_radius(corner, button_style.get_corner_radius(corner))
		_fill_style.corner_detail = button_style.corner_detail
	button_down.connect(_set_held.bind(true))
	button_up.connect(_set_held.bind(false))
	_icon = TextureRect.new()
	_label = Label.new()
	_row = HBoxContainer.new()
	var row := _row
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", ICON_GAP)
	_icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme_type_variation = &"SmallStrongLabel"
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	row.add_child(_label)
	add_child(row)
	_game = ServeMinigamePrototype.new()
	_game.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.fed.connect(fed.emit)
	add_child(_game)


## Shows the request's [param label] and [param request_icon], centred together.
func show_request(label: String, request_icon: Texture2D) -> void:
	if _label.text != label:
		_label.text = label
	_icon.texture = request_icon
	_icon.visible = request_icon != null
	_game.request_label = label
	_row.modulate.a = _game.get_label_alpha()


func _gui_input(event: InputEvent) -> void:
	if not disabled:
		_game.handle(event)


func _notification(what: int) -> void:
	# Hidden while held, as when the request is served, it never sees the release.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_set_held(false)


func _draw() -> void:
	if progress > 0.0:
		draw_style_box(_fill_style, Rect2(Vector2.ZERO, Vector2(size.x * progress, size.y)))


## Whether the button is held down.
func is_held() -> bool:
	return _held


## Lets go, as when the card turns the button off.
func release() -> void:
	_set_held(false)


func _set_held(held: bool) -> void:
	if held == _held or (held and _game.is_playing()):
		return
	_held = held
	hold_changed.emit(held)
