class_name UpgradeButton
extends Control
## One upgrade in the research screen: a rounded square tile with its icon, and, where its
## title ends in a step ("Speed 2", "Bigger portions II"), that step as a numeral in the
## top left corner. It shows its [enum Research.State] in the shades of the race whose
## points it costs most ([method Upgrade.get_race]):
## researched is lit, a gradient in the race's colour with a glow and the icon in its deep
## shade; available is a dark gradient with a border in the race's colour and its glow;
## can't afford is flat with a faint border, a dim icon and a red badge for what the player
## lacks; locked is flat and dim; and hidden or needing a promotion is a dark silhouette of
## its icon. Holding it down while available sweeps a fill up from the bottom; held for
## [constant HOLD_SECONDS] it tells its parent, which researches it, and once researched the
## fill fades off the lit tile as it pops. Letting go or leaving it first drains the fill.
## A press on one that can't be researched flashes its border, and pulses the badge of one
## the player can't afford. A click sounds as a hold completes, and another for a press it
## can't act on. [method reveal] fades it in from a silhouette, as a stage
## opens. Under Reduce motion nothing pops or pulses; the fades and flashes stay. The pointer
## over it opens its [Tooltip] at once, above it, so it never covers the rows under it;
## the parent fills it ([UpgradeTooltip]).

## It was held down long enough to research it.
signal held

const SIZE := Vector2(52, 52)
const RADIUS := TilePaint.RADIUS
## The icon's size and its offset from the tile's corner, in pixels.
const ICON_SIZE := 24.0
## Seconds it has to be held to research it, and the fill takes to drain, easing out:
## after a let-go, and off the lit tile once researched.
const HOLD_SECONDS := 0.6
const DRAIN_SECONDS := 0.2
const DONE_SECONDS := 0.15
## The pop once researched, as the research count's: how big, and seconds up and back.
const POP_SCALE := 1.06
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14
## A press it can't act on: seconds the border flash fades over, and the badge's pulse.
const FLASH_SECONDS := 0.3
const PULSE_SCALE := 1.15
const PULSE_UP_SECONDS := 0.07
const PULSE_DOWN_SECONDS := 0.13
## Seconds to fade in from a silhouette as its stage opens.
const REVEAL_SECONDS := 0.3
## The hold fill: the fuel's cyan, faint, as the other hold buttons' fills.
const HOLD_COLOR := Color(0.6, 0.949, 1.0, 0.35)
## What the player lacks, on the badge and on the card.
const LACKING_COLOR := Color("f24d66")

## Each race's tile shades: a researched tile's gradient from top to bottom, its top
## highlight, the line from it once researched, and the deep shade of its icon.
const SHADES: Dictionary[Race.Type, Dictionary] = {
	Race.Type.BLUE:
	{
		&"top": Color("9dbdff"),
		&"bottom": Color("4f7fee"),
		&"highlight": Color("c2d6ff"),
		&"line": Color("a9c6ff"),
		&"ink": Color("2e3d8c"),
	},
	Race.Type.ORANGE:
	{
		&"top": Color("ffb888"),
		&"bottom": Color("f06a1c"),
		&"highlight": Color("ffd2b3"),
		&"line": Color("ffc29a"),
		&"ink": Color("7a2e10"),
	},
	Race.Type.GREEN:
	{
		&"top": Color("c9f7ae"),
		&"bottom": Color("7cd452"),
		&"highlight": Color("e0fbd0"),
		&"line": Color("cff7b8"),
		&"ink": Color("296138"),
	},
}
## An available tile's gradient, from top to bottom.
const DARK_TOP := Color("4a3d7a")
const DARK_BOTTOM := Color("281f47")
## Flat tiles: can't afford, locked, and a silhouette (hidden or needing a promotion).
const UNAFFORDABLE_COLOR := Color("2f2757")
const LOCKED_COLOR := Color("2a2450")
const SILHOUETTE_COLOR := Color("302859")
## A silhouette's icon.
const SILHOUETTE_INK := Color("0b0920")
const TEXT_COLOR := Color("f4f1ff")
const BADGE_COLOR := Color("1b1740")
const BADGE_RADIUS := 8.0
const BADGE_ICON_SIZE := 10.0
const DOLLAR := preload("res://game/solar_system/icons/dollar_sign.svg")
const FLASK := preload("res://game/solar_system/icons/flask_conical.svg")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
## Placeholder clicks: once a hold completes, and for a press it can't act on.
const HELD_SOUND := preload("res://ui/audio/ui_click.ogg")
const REFUSED_SOUND := preload("res://ui/audio/key_click.ogg")
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

var upgrade: Upgrade:
	set(value):
		upgrade = value
		if is_node_ready():
			_show_state()

var _state := Research.State.LOCKED
## What the player lacks for it, shown on the badge while it can't be afforded.
var _lacks_points := false
var _hover := false
var _holding := false
var _progress := 0.0
# Held to the end, and waiting for the parent's research to show as researched.
var _researching := false
var _drain: Tween
var _pop: Tween
# A press it can't act on, from 1 fading to 0, and the badge's size.
var _flash := 0.0
var _badge_scale := 1.0
var _nudge: Tween
# How much the silhouette still covers it while it is revealed, from 1 to 0.
var _veil := 0.0
var _reveal: Tween
var _ink := TEXT_COLOR
var _icon := TextureRect.new()
var _step := Label.new()
var _badge_icon := TextureRect.new()
var _tooltip := TOOLTIP.instantiate() as Tooltip


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = (SIZE - Vector2.ONE * ICON_SIZE) * 0.5
	_icon.size = Vector2.ONE * ICON_SIZE
	add_child(_icon)
	_step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step.theme_type_variation = &"SmallStrongLabel"
	_step.add_theme_font_size_override(&"font_size", 13)
	_step.position = Vector2(6, 0)
	add_child(_step)
	_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge_icon.size = Vector2.ONE * BADGE_ICON_SIZE
	_badge_icon.position = _badge_center() - _badge_icon.size * 0.5
	_badge_icon.modulate = LACKING_COLOR
	_badge_icon.pivot_offset = _badge_icon.size * 0.5
	add_child(_badge_icon)
	pivot_offset = SIZE * 0.5
	# Read tile after tile, it can't keep the pointer waiting.
	_tooltip.target = self
	_tooltip.rest_seconds = 0.0
	# Above it, so the tooltip covers neither the rows under it that this one opens nor the
	# tiles beside it.
	_tooltip.side = Tooltip.Side.ABOVE
	add_child(_tooltip)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _ready() -> void:
	# Godot turns processing on at ready for a script with _process(); it runs only held.
	set_process(false)
	_show_state()


## Shows [param state]; [param lacks_points] says whether, unaffordable, the player lacks
## research points rather than only credits.
func show_state(state: Research.State, lacks_points := false) -> void:
	if state == _state and lacks_points == _lacks_points:
		return
	_state = state
	_lacks_points = lacks_points
	if state != Research.State.AVAILABLE and _holding:
		_set_holding(false)
	if state == Research.State.RESEARCHED and _researching:
		_researching = false
		_pop_tile()
	_show_state()


## Fades it in from a silhouette after [param delay] seconds, as its stage opens.
func reveal(delay: float) -> void:
	if _reveal:
		_reveal.kill()
	_set_veil(1.0)
	_reveal = create_tween()
	_reveal.tween_interval(delay)
	_reveal.tween_method(_set_veil, 1.0, 0.0, REVEAL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)


## The state it shows.
func get_state() -> Research.State:
	return _state


## Its tooltip, for the parent to fill.
func get_info_tooltip() -> Tooltip:
	return _tooltip


## How far the hold has filled it, from 0 to 1.
func get_hold_progress() -> float:
	return _progress


## The colour of a line from it once researched: its race's light shade.
func get_line_color() -> Color:
	return _shades()[&"line"]


## The colour of its glow: its race's skin colour.
func get_accent() -> Color:
	return Race.SKIN_COLORS[upgrade.get_race()] if upgrade else Color.WHITE


## The step at the end of [param title] as a Roman numeral, "II" for "Speed 2" or for
## "Bigger portions II", or "" where it ends in none.
static func step_of(title: String) -> String:
	var last := title.get_slice(" ", title.get_slice_count(" ") - 1)
	if title.get_slice_count(" ") < 2:
		return ""
	if last.is_valid_int() and last.to_int() > 0 and last.to_int() < ROMAN.size():
		return ROMAN[last.to_int()]
	return last if last in ROMAN and not last.is_empty() else ""


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if not click or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if click.pressed and _state != Research.State.AVAILABLE:
		_nudge_tile()
	_set_holding(click.pressed and _state == Research.State.AVAILABLE)


# The fill sweeps up evenly while held.
func _process(delta: float) -> void:
	if not _holding:
		set_process(false)
		return
	_set_progress(minf(_progress + delta / HOLD_SECONDS, 1.0))
	if _progress < 1.0:
		return
	_holding = false
	set_process(false)
	_researching = true
	Audio.play_sfx(HELD_SOUND)
	held.emit()
	_drain_fill(DONE_SECONDS)


func _notification(what: int) -> void:
	# Hidden while held, as when the screen closes, it never sees the release.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_holding = false
		_researching = false
		set_process(false)
		if _drain:
			_drain.kill()
		_set_progress(0.0)


func _set_holding(holding: bool) -> void:
	if holding == _holding:
		return
	_holding = holding
	set_process(holding)
	if holding:
		if _drain:
			_drain.kill()
	else:
		_drain_fill(DRAIN_SECONDS)


# Drains the fill over [param seconds], fast at first: the response to a let-go snaps.
func _drain_fill(seconds: float) -> void:
	if _drain:
		_drain.kill()
	if _progress <= 0.0:
		_researching = false
		return
	_drain = create_tween()
	(
		_drain
		. tween_method(_set_progress, _progress, 0.0, seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_drain.tween_callback(func() -> void: _researching = false)


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


# Swells a little and settles, as the research count pops.
func _pop_tile() -> void:
	if Settings.reduce_motion:
		return
	if _pop:
		_pop.kill()
	scale = Vector2.ONE
	_pop = create_tween()
	_pop.tween_property(self, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		_pop
		. tween_property(self, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


# A press it can't act on: the border flashes, and the badge of one the player can't afford
# pulses, so the player looks at what is lacking.
func _nudge_tile() -> void:
	Audio.play_sfx(REFUSED_SOUND)
	if _nudge:
		_nudge.kill()
	_nudge = create_tween().set_parallel()
	_nudge.tween_method(_set_flash, 1.0, 0.0, FLASH_SECONDS).set_ease(Tween.EASE_OUT)
	if _state != Research.State.UNAFFORDABLE or Settings.reduce_motion:
		return
	_nudge.tween_method(_set_badge_scale, 1.0, PULSE_SCALE, PULSE_UP_SECONDS)
	(
		_nudge
		. tween_method(_set_badge_scale, PULSE_SCALE, 1.0, PULSE_DOWN_SECONDS)
		. set_delay(PULSE_UP_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _set_badge_scale(value: float) -> void:
	_badge_scale = value
	_badge_icon.scale = Vector2.ONE * value
	queue_redraw()


func _set_veil(value: float) -> void:
	_veil = value
	_apply_ink()
	queue_redraw()


# The icon, the numeral and the badge's icon in their state's colours, under the veil.
func _apply_ink() -> void:
	var base := SILHOUETTE_INK if _silhouette() else _ink
	_icon.modulate = base.lerp(SILHOUETTE_INK, _veil)
	_step.modulate.a = 1.0 - _veil
	_badge_icon.modulate.a = 1.0 - _veil


func _shades() -> Dictionary:
	return SHADES[upgrade.get_race() if upgrade else Race.Type.BLUE]


func _silhouette() -> bool:
	return _state == Research.State.HIDDEN or _state == Research.State.NEEDS_PROMOTION


func _show_state() -> void:
	var shades := _shades()
	var ink := TEXT_COLOR
	match _state:
		Research.State.RESEARCHED:
			ink = shades[&"ink"]
		Research.State.UNAFFORDABLE:
			ink = Color(TEXT_COLOR, 0.45)
		Research.State.LOCKED:
			ink = Color(TEXT_COLOR, 0.4)
	_icon.texture = upgrade.icon if upgrade else null
	_ink = ink
	_apply_ink()
	_step.text = "" if _silhouette() or not upgrade else step_of(upgrade.title)
	var step_ink := ink
	if _state == Research.State.UNAFFORDABLE:
		step_ink = Color(TEXT_COLOR, 0.4)
	_step.add_theme_color_override(&"font_color", step_ink)
	_badge_icon.visible = _state == Research.State.UNAFFORDABLE
	_badge_icon.texture = FLASK if _lacks_points else DOLLAR
	var available := _state == Research.State.AVAILABLE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if available else CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SIZE)
	var shades := _shades()
	var accent := get_accent()
	# The glows grow in under the veil as it lifts.
	var lift := 1.0 - _veil
	match _state:
		Research.State.RESEARCHED:
			# The design's order: the glow first, the drop shadow over it.
			TilePaint.shadow(self, rect, Color(accent, 0.6 * lift), 16.0, Vector2.ZERO)
			TilePaint.shadow(self, rect, Color(0, 0, 0, 0.4 * lift), 8.0, Vector2(0, 5))
			TilePaint.body(self, rect, shades[&"top"], shades[&"bottom"])
			var light: Color = shades[&"highlight"]
			TilePaint.top_highlight(self, rect, light.lightened(0.3) if _hover else light)
		Research.State.AVAILABLE:
			TilePaint.shadow(self, rect, Color(0, 0, 0, 0.5 * lift), 10.0, Vector2(0, 5))
			TilePaint.shadow(self, rect, Color(accent, 0.6 * lift), 12.0, Vector2.ZERO)
			TilePaint.body(self, rect, DARK_TOP, DARK_BOTTOM)
			TilePaint.border(self, rect, accent.lightened(0.35) if _hover else accent, 2.0)
		Research.State.UNAFFORDABLE:
			TilePaint.body(self, rect, UNAFFORDABLE_COLOR, UNAFFORDABLE_COLOR)
			var edge := (0.6 if _hover else 0.4) + 0.4 * _flash
			TilePaint.border(self, rect, Color(accent, minf(edge, 1.0)), 1.5)
		Research.State.LOCKED:
			TilePaint.body(self, rect, LOCKED_COLOR, LOCKED_COLOR)
			var edge := (0.12 if _hover else 0.0) + 0.3 * _flash
			if edge > 0.0:
				TilePaint.border(self, rect, Color(1, 1, 1, edge), 1.0)
		_:
			_draw_silhouette(rect, 1.0)
	if _veil > 0.0 and not _silhouette():
		_draw_silhouette(rect, _veil)
	if _progress > 0.0:
		var filled := Rect2(0, SIZE.y * (1.0 - _progress), SIZE.x, SIZE.y * _progress)
		for part: PackedVector2Array in Geometry2D.intersect_polygons(
			TilePaint.rounded(rect, RADIUS), TilePaint.rect_points(filled)
		):
			draw_colored_polygon(part, HOLD_COLOR)
	if _state == Research.State.UNAFFORDABLE:
		var radius := BADGE_RADIUS * _badge_scale
		var ring := LACKING_COLOR.lerp(Color.WHITE, 0.5 * _flash)
		draw_circle(_badge_center(), radius, Color(BADGE_COLOR, lift), true, -1.0, true)
		draw_circle(_badge_center(), radius - 0.5, Color(ring, lift), false, 1.0, true)


# The silhouette's flat tile and faint border, at [param strength] over what is under it.
func _draw_silhouette(rect: Rect2, strength: float) -> void:
	TilePaint.body(self, rect, Color(SILHOUETTE_COLOR, strength), Color(SILHOUETTE_COLOR, strength))
	var edge := (0.2 if _hover else 0.12) + 0.3 * _flash
	TilePaint.border(self, rect, Color(1, 1, 1, edge * strength), 1.0)


func _badge_center() -> Vector2:
	return Vector2(SIZE.x - 3.0, 3.0)


func _on_mouse_entered() -> void:
	_hover = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false
	_set_holding(false)
	queue_redraw()
