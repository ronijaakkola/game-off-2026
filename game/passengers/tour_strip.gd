class_name TourStrip
extends MarginContainer
## The stops of a VIP's [Tour], in a row under their card on the On board panel, starting
## under the card's text: a gold tick for each stop made, the stop they are on as its
## planet's icon and name, and those to come as fainter icons, joined by short links that
## turn gold as the tour passes them. At the right, the time left for the whole tour on
## their ride's clock ("1:24"), which reads "Late" in red once it is gone.
## When they make a stop, the row is laid out anew at once and what changed comes in: the
## new tick grows into place, the link after it turns gold, the next stop's icon brightens
## and its name fades in a beat later. Under Reduce motion the tick only fades.

const CHECK := preload("res://shared/icons/circle_check.svg")
## Pixels from the card's left edge to its text, and from the card down to the row.
const INDENT := 56
const GAP_ABOVE := 6
const ICON_SIZE := 12.0
const LINK_SIZE := Vector2(6.0, 2.0)
const FONT_SIZE := 11
const LATER_OPACITY := 0.45
const FAINT := Color(0.957, 0.945, 1.0, 0.4)
const LATE_COLOR := Color(0.949, 0.302, 0.4)
const LATE_TEXT := "Late"
## Seconds it takes to fade in, with its card.
const FADE_SECONDS := 0.35
## A stop made: the scale the tick grows from, the seconds it takes and its fade, then the
## seconds the link, the next icon and its name take, the name after a beat.
const TICK_FROM := 0.6
const TICK_SECONDS := 0.3
const TICK_FADE_SECONDS := 0.12
const NEXT_SECONDS := 0.2
const NAME_DELAY := 0.08

## Whose tour it shows. Set it before the strip is in the tree.
var passenger: Passenger

var _row := HBoxContainer.new()
var _time: Label
var _done := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"margin_left", INDENT)
	add_theme_constant_override(&"margin_top", GAP_ABOVE)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override(&"separation", 4)
	add_child(_row)
	_fill()


func _process(_delta: float) -> void:
	if not passenger or not passenger.tour:
		return
	if passenger.tour.done != _done:
		_fill(_done >= 0)
	_show_time()


## Fades the strip in, as its card slides in.
func fade_in() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, ^"modulate:a", 1.0, FADE_SECONDS)


# Lays the row out as the tour stands. [param moved] brings in what a stop just made
# changed.
func _fill(moved := false) -> void:
	for part: Node in _row.get_children():
		_row.remove_child(part)
		part.queue_free()
	if not passenger or not passenger.tour:
		return
	var tour := passenger.tour
	_done = tour.done
	for i: int in tour.stops.size():
		# What the stop just made changed: its tick, and the link and the stop after it.
		var fresh := moved and i == _done
		if i > 0:
			var link := _make_link(i <= _done)
			_row.add_child(link)
			if fresh:
				link.color = FAINT
				create_tween().tween_property(link, ^"color", Vip.GOLD, NEXT_SECONDS)
		if i < _done:
			_row.add_child(_make_tick(moved and i == _done - 1))
			continue
		var icon := _make_icon(tour.stops[i], i == _done)
		_row.add_child(icon)
		if i != _done:
			continue
		var stop := _make_label(tour.stops[i].display_name, Color.WHITE)
		_row.add_child(stop)
		if fresh:
			icon.modulate.a = LATER_OPACITY
			create_tween().tween_property(icon, ^"modulate:a", 1.0, NEXT_SECONDS)
			stop.modulate.a = 0.0
			var fade := create_tween().tween_property(stop, ^"modulate:a", 1.0, NEXT_SECONDS)
			fade.set_delay(NAME_DELAY)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(spacer)
	_time = _make_label("", Vip.GOLD)
	_row.add_child(_time)
	_show_time()


func _show_time() -> void:
	var left := passenger.ride.get_seconds_left()
	var text := Vip.format_time(left) if left > 0.0 else LATE_TEXT
	if _time.text == text:
		return
	_time.text = text
	_time.add_theme_color_override(&"font_color", Vip.GOLD if left > 0.0 else LATE_COLOR)


func _make_link(passed: bool) -> ColorRect:
	var link := ColorRect.new()
	link.custom_minimum_size = LINK_SIZE
	link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	link.color = Vip.GOLD if passed else FAINT
	link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return link


# A stop made. The tick sits in a slot of its own, since the row would undo its scale.
# [param growing], it grows into place past its size and fades in.
func _make_tick(growing := false) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2.ONE * ICON_SIZE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tick := TextureRect.new()
	tick.texture = CHECK
	tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tick.size = Vector2.ONE * ICON_SIZE
	tick.pivot_offset = tick.size * 0.5
	tick.self_modulate = Vip.GOLD
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(tick)
	if growing:
		tick.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(tick, ^"modulate:a", 1.0, TICK_FADE_SECONDS)
		if not Settings.reduce_motion:
			tick.scale = Vector2.ONE * TICK_FROM
			(
				tween
				. tween_property(tick, ^"scale", Vector2.ONE, TICK_SECONDS)
				. set_trans(Tween.TRANS_BACK)
				. set_ease(Tween.EASE_OUT)
			)
	return slot


func _make_icon(planet: Planet, current: bool) -> PlanetIcon:
	var icon := PlanetIcon.new()
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.planet = planet
	icon.modulate.a = 1.0 if current else LATER_OPACITY
	return icon


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"StrongLabel"
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)
	label.text = text
	return label
