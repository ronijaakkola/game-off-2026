extends PanelContainer
## PROTOTYPE, throwaway (variant A of [ControlsPrototype]): a legend in the bottom right
## corner that says what a right click does now. With no route, one row: right click sets
## a route. With a route, that row morphs to "Start a new route" and a second row opens
## under it: the queue key + right click adds a stop. While the queue key is held the
## second row lights up and the first dims. It follows the route and the key, never what
## the pointer is over, so it changes a few times a minute, not on every move.
## It hides with the bus bars, and while a right click would do nothing.
## For captures, `route` after `--` sets a route through two planets and `held` holds the
## queue key down.

const GLASS := preload("res://ui/glass.tres")
const THEME := preload("res://ui/theme.tres")
const MARGIN := 12.0
const ROW_HEIGHT := 20.0
## Wide enough for the longest text, so the panel never changes width.
const WIDTH := 190.0
## The width of the icons' column: the queue key, a plus and the mouse.
const ICON_ROOM := 54.0
const OPEN_SECONDS := 0.25
const FADE_SECONDS := 0.2
const DIM := 0.45
const QUIET := 0.7
const TEXT_COLOR := Color(0.957, 0.945, 1.0, 1.0)

@export var bus: FrameshiftBus
@export var bars: Control
@export var tutorial: Tutorial
## The HUD's block on clicks, up while a call covers the screen.
@export var click_block: Control
@export var star_map: StarMap

var _set_row: Control
var _add_row: Control
var _set_label: MorphLabel
# How open the second row is, 0 to 1.
var _openness := 0.0
var _shown := 0.0


func _ready() -> void:
	ControlsPrototype.read_args()
	material = GLASS
	theme = THEME
	var style := THEME.get_stylebox(&"panel", &"RouteBarPanel").duplicate() as StyleBoxFlat
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	add_theme_stylebox_override(&"panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	custom_minimum_size.x = WIDTH
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", 0)
	add_child(rows)
	_set_row = _make_row("{mouse_right}", "Set a route")
	_set_label = _set_row.get_child(0).get_child(1) as MorphLabel
	rows.add_child(_set_row)
	_add_row = _make_row(QueueKey.get_icons() + "+{mouse_right}", "Add a stop")
	rows.add_child(_add_row)
	modulate.a = 0.0
	var group := "Controls prototype"
	for value: int in ControlsPrototype.Variant.values():
		var text := String(ControlsPrototype.Variant.keys()[value]).capitalize()
		DebugPanel.add_button(text, _debug_show.bind(value), self, group)
	_debug_set_up.call_deferred()


func _process(delta: float) -> void:
	var has_route := bus != null and not bus.get_route_stops().is_empty()
	var can_route := _can_route()
	ControlsPrototype.can_route = can_route
	var showing := can_route and ControlsPrototype.shows_legend() and bars and bars.visible
	_shown = move_toward(_shown, 1.0 if showing else 0.0, delta / FADE_SECONDS)
	modulate.a = _shown * (bars.modulate.a if bars else 1.0)
	visible = modulate.a > 0.0
	_set_label.morph_to("Start a new route" if has_route else "Set a route")
	var still := Settings.reduce_motion or not visible
	var target := 1.0 if has_route else 0.0
	_openness = target if still else move_toward(_openness, target, delta / OPEN_SECONDS)
	var eased := 1.0 - pow(1.0 - _openness, 3.0)
	_add_row.custom_minimum_size.y = ROW_HEIGHT * eased
	var held := QueueKey.is_held() and has_route
	var weight := 1.0 - exp(-14.0 * delta)
	_set_row.modulate.a = lerpf(_set_row.modulate.a, DIM if held else 1.0, weight)
	var add_alpha := (1.0 if held else QUIET) * eased
	_add_row.modulate.a = lerpf(_add_row.modulate.a, add_alpha, weight)


func _can_route() -> bool:
	if not bus or (tutorial and tutorial.is_running()):
		return false
	if click_block and click_block.visible:
		return false
	return not (bus.route_locked or bus.is_towing() or bus.get_fuel_tank().is_empty())


# A row: its icons, right-aligned in their column so the mice line up, then its text. It
# clips, so it can open from no height.
func _make_row(icons: String, text: String) -> Control:
	var room := Control.new()
	room.clip_contents = true
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.custom_minimum_size.y = ROW_HEIGHT
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.custom_minimum_size.y = ROW_HEIGHT
	room.add_child(row)
	var keys := HBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.custom_minimum_size.x = ICON_ROOM
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.add_theme_constant_override(&"separation", 3)
	row.add_child(keys)
	for part: String in icons.split("+"):
		if keys.get_child_count() > 0:
			var plus := Label.new()
			plus.theme_type_variation = &"SmallStrongLabel"
			plus.text = "+"
			plus.modulate.a = 0.6
			keys.add_child(plus)
		var icon := TextureRect.new()
		icon.texture = ControlIcons.ICONS[part.trim_prefix("{").trim_suffix("}")]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var shape := icon.texture.get_size()
		icon.custom_minimum_size = Vector2(shape.x / shape.y, 1.0) * ControlIcons.HEIGHT
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys.add_child(icon)
	var label := MorphLabel.new()
	label.theme_type_variation = &"StrongLabel"
	label.add_theme_color_override(&"font_color", TEXT_COLOR)
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return room


func _debug_show(value: int) -> void:
	ControlsPrototype.variant = value as ControlsPrototype.Variant


# For captures: a route through two planets, and the queue key held down.
func _debug_set_up() -> void:
	var args := OS.get_cmdline_user_args()
	if "route" in args and bus and star_map:
		var planets := star_map.get_active_planets()
		planets.erase(bus.get_docked_planet())
		for planet: Planet in planets.slice(0, 2):
			bus.plot_course(RouteStop.at_planet(planet), true)
	if "held" in args:
		Input.action_press(&"queue_stop")
