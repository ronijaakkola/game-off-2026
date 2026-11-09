class_name UpgradeButton
extends PanelContainer
## One upgrade in a drawn research tree: a square tile with its icon, which shows its
## [enum Research.State] in one of three looks, in the accent of the race whose points it
## costs ([method Upgrade.get_race]), its skin colour: available (whether or not the player
## can pay yet) is a dark tile with an accent border, researched is filled with the accent
## with the icon in the race's deep colour, and not available (locked or hidden) is a flat,
## dim tile, a hidden one showing "?" in place of its icon. Its name and cost
## are on the card the pointer shows. Until it has an icon, it shows its title's first
## letter. It tells its parent when the pointer comes or goes and when it is clicked; the
## parent decides what a click does.

## The pointer came over it.
signal hovered
## The pointer left it.
signal unhovered
## It was clicked with the left button.
signal clicked

## Square, unless [member tile_size] says otherwise. Its content must fit inside, margins
## included, or the tile grows taller: the letter's line is 45 pixels high.
const SIZE := Vector2(64, 64)
## The icon's size in a tile of [constant SIZE], in pixels; it scales with
## [member tile_size]. Icons are imported at twice their 24 pixels, so they stay sharp at
## this size.
const ICON_SIZE := 32.0
## The letter's font size in a tile of [constant SIZE], the HeadingLabel's; it scales with
## [member tile_size].
const LETTER_FONT_SIZE := 32
## The margin round the icon and the corners' radius in a tile of [constant SIZE]; they
## scale with [member tile_size].
const MARGIN := 6.0
## The accent of an upgrade that costs no research points and so has no race.
const RESEARCHED_COLOR := Color(0.6, 0.95, 1.0)
const LACKING_COLOR := Color(1.0, 0.45, 0.42)
## An available upgrade's tile, under its accent border.
const DARK_COLOR := Color(0.1, 0.08, 0.17)
## An upgrade that isn't available yet: locked or hidden.
const DISABLED_COLOR := Color(1, 1, 1, 0.04)

var upgrade: Upgrade
## The side of the square tile, in pixels: [constant SIZE] in a planet's panel, smaller
## where many trees show at once. The icon, the letter, the margin and the corners scale
## with it.
var tile_size := SIZE.x:
	set(value):
		tile_size = value
		_apply_size()

var _state := Research.State.LOCKED
var _style := StyleBoxFlat.new()
var _icon := TextureRect.new()
var _letter := Label.new()
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style.set_border_width_all(2)
	add_theme_stylebox_override(&"panel", _style)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_icon)
	_letter.theme_type_variation = &"HeadingLabel"
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_letter)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_size()


func _ready() -> void:
	_show_state()


## Shows [param state].
func show_state(state: Research.State) -> void:
	_state = state
	_show_state()


## The state it shows.
func get_state() -> Research.State:
	return _state


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func _apply_size() -> void:
	var scale_by := tile_size / SIZE.x
	custom_minimum_size = Vector2(tile_size, tile_size)
	_icon.custom_minimum_size = Vector2.ONE * roundf(ICON_SIZE * scale_by)
	_letter.add_theme_font_size_override(&"font_size", roundi(LETTER_FONT_SIZE * scale_by))
	var margin := maxi(roundi(MARGIN * scale_by), 2)
	_style.set_corner_radius_all(margin)
	_style.set_content_margin_all(margin)


func _show_state() -> void:
	var hidden_now := _state == Research.State.HIDDEN
	var icon := upgrade.icon if upgrade else null
	_icon.texture = icon
	# A hidden upgrade shows "?" in place of its icon, so its icon gives nothing away.
	_icon.visible = icon != null and not hidden_now
	_letter.visible = not _icon.visible
	if hidden_now:
		_letter.text = "?"
	elif upgrade and not upgrade.title.is_empty():
		_letter.text = upgrade.title.left(1)
	var accent := RESEARCHED_COLOR
	var deep := DARK_COLOR
	if upgrade and not upgrade.points.is_empty():
		accent = Race.SKIN_COLORS[upgrade.get_race()]
		deep = Race.BACKDROP_COLORS[upgrade.get_race()]
	var researched := _state == Research.State.RESEARCHED
	var open := _state == Research.State.AVAILABLE or _state == Research.State.UNAFFORDABLE
	var ink := Color(1, 1, 1, 0.3)
	if researched:
		ink = deep
	elif open:
		ink = Color.WHITE
	_icon.modulate = ink
	_letter.modulate = ink
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if open else CURSOR_ARROW
	if researched:
		_style.bg_color = accent
		_style.border_color = accent.lightened(0.4) if _hover else accent
	elif open:
		_style.bg_color = DARK_COLOR
		_style.border_color = accent.lightened(0.4) if _hover else accent
	else:
		_style.bg_color = DISABLED_COLOR
		_style.border_color = Color(1, 1, 1, 0.18 if _hover else 0.06)


func _on_mouse_entered() -> void:
	_hover = true
	_show_state()
	hovered.emit()


func _on_mouse_exited() -> void:
	_hover = false
	_show_state()
	unhovered.emit()
