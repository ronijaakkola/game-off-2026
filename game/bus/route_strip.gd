class_name RouteStrip
extends Control
## The route bar's line: the stops the route bar hands it, as icons along one line drawn
## to scale, so a long leg is a long link, with the bus on it. The first stop is where the
## line starts. A planet shows as its icon, a point in space as a small diamond. It shows
## at most [constant MOST_STOPS] and folds the rest into a "+N" chip; the links shrink to
## fit, none under [constant MIN_LINK] pixels, and the first, where the bus is, keeps
## [constant MIN_CURRENT_LINK].
## Each icon belongs to its [RouteStop], so the same planet twice is two icons. When the
## stops change, every icon and the bus glide to their new places, from wherever they are,
## so clicks in quick succession never jump. A new stop slides in from just past its place
## while it grows and fades in; one taken off fades and shrinks where it is. The start
## leaving, as when the bus docks on its way, slides off to the left, taking the flown part
## of the line with it, and the bus, which waits just past the start, drives over the
## planet that becomes the new one. The bus has room round it: the line and any planet
## under it are cut away there, so the bar's glass shows between. Under Reduce motion
## nothing slides or grows: icons fade in and out where they stand and the rest cuts to
## place.
## The pointer over an icon rings it and opens a tooltip with the planet's name. When
## [member can_remove] allows it, a [RemoveBadge] shows on the icon's top right corner, and
## clicking it asks for the stop to come off with [signal remove_pressed].

## The player clicked the X on [param stop]'s icon.
signal remove_pressed(stop: RouteStop)

const ICON := 16.0
## Pixels between an icon and the link next to it.
const GAP := 2.0
const MIN_LINK := 14.0
const MIN_CURRENT_LINK := 40.0
const MOST_STOPS := 7
const CHIP_WIDTH := 24.0
## As tall as a planet's disc in its icon.
const CHIP_HEIGHT := 14.0
const CHIP_GAP := 6.0
const CHIP_FONT_SIZE := 10
const FLOWN_COLOR := Color(1.0, 0.6, 0.22, 1.0)
const AHEAD_COLOR := Color(1.0, 1.0, 1.0, 0.1412)
const BUS_COLOR := Color(0.96, 0.78, 0.29, 1.0)
## The bus's room: nothing under it is drawn within this radius of its middle, so the
## bar's glass shows through round it, a clean bite out of the line and of a planet it
## sits on.
const BUS_ROOM := 10.0
## The shortest piece of a link drawn beside the bus; a shorter one would read as a
## sliver poking out from under it.
const SHORTEST_PIECE := 3.0
const BUS_ICON := 14.0
const POINT_COLOR := Color(0.957, 0.945, 1.0, 0.651)
const POINT_ICON := 9.0
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const CHIP_COLOR := Color(1.0, 1.0, 1.0, 0.07)
# Where the bus's middle sits: past the start's right edge while it waits there, just
# short of a planet it docks at on the way, its nose at the edge, and clear of the last.
const WAIT_OFFSET := 9.0
const DOCK_OFFSET := 4.0
const END_OFFSET := 13.0
## How fast icons and the bus glide to a new place: the share of the way left they cover
## per second, which eases out, most of the way in a quarter second.
const GLIDE_RATE := 12.0
## Seconds a new icon takes to come in, and one taken off to go.
const ENTER_SECONDS := 0.25
const EXIT_SECONDS := 0.15
## The scale an icon grows from and shrinks to, and how far past its place it slides in.
const ENTER_SCALE := 0.5
const ENTER_SLIDE := 8.0

const BUS_TEXTURE := preload("res://game/bus/icons/bus.svg")
const POINT_TEXTURE := preload("res://game/bus/icons/diamond.svg")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
## Where the X's middle sits from the icon's top right corner.
const BADGE_OFFSET := Vector2(-2.0, 1.0)

## Whether a stop's icon offers the X: called with the stop, returns a bool. Unset, none do.
var can_remove: Callable

# Every icon drawn, by its stop, those going too, and where each heads.
var _icons := {}
var _targets := {}
var _fades := {}
# The stops whose icons are going, as keys.
var _leaving := {}
# The icons in line order, those going among them where they were.
var _order: Array[RouteStop] = []
# The stops shown, in order, without those going.
var _shown: Array[RouteStop] = []
# How far along the first link the bus is, 0 to 1, or -1 while it waits at the start.
var _progress := -1.0
var _bus_x := 0.0
var _bus_target := 0.0
var _hovered: Control
# Each icon's X, by the icon.
var _badges := {}
var _bus: Control
var _chip: Control
var _chip_text := ""
var _chip_target := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = Control.new()
	_chip.size = Vector2(CHIP_WIDTH, ICON)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.draw.connect(_draw_chip)
	_chip.visible = false
	add_child(_chip)
	_bus = Control.new()
	_bus.size = Vector2.ONE * BUS_ROOM * 2.0
	_bus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bus.draw.connect(_draw_bus)
	_bus.visible = false
	add_child(_bus)


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-GLIDE_RATE * delta)
	for stop: RouteStop in _icons:
		var icon := _icons[stop] as Control
		icon.position.x = lerpf(icon.position.x, _targets[stop], weight)
	_bus_x = lerpf(_bus_x, _bus_target, weight)
	_bus.position = Vector2(_bus_x - BUS_ROOM, ICON * 0.5 - BUS_ROOM)
	_chip.position.x = lerpf(_chip.position.x, _chip_target, weight)
	_cut_planets()
	queue_redraw()


## Shows [param stops] along the line, the first where it starts, with [param legs] the
## length of each leg from one to the next, in any unit, and the bus [param progress] of
## the way along the first, from 0 to 1, or waiting at the start with -1. With
## [param at_once], as when the bar opens, everything is placed with no motion.
func show_route(
	stops: Array[RouteStop], legs: PackedFloat32Array, progress: float, at_once := false
) -> void:
	var still := at_once or Settings.reduce_motion
	var shown: Array[RouteStop] = stops.slice(0, MOST_STOPS)
	var hidden := stops.size() - shown.size()
	for stop: RouteStop in _shown:
		if not shown.has(stop):
			_leave(stop, at_once)
	_order = _merged(_order, shown)
	_shown = shown
	_progress = progress
	var links := _link_widths(legs.slice(0, maxi(shown.size() - 1, 0)), hidden > 0)
	# Whole pixels as the links add up, not each link rounded, so the errors never pile up
	# at the far end: the start and the last stop stay put however the legs change.
	var exact := 0.0
	var x := 0.0
	for i: int in shown.size():
		var stop := shown[i]
		x = roundf(exact)
		_targets[stop] = x
		if not _icons.has(stop):
			_enter(stop, x, at_once)
		elif _leaving.has(stop):
			_come_back(stop, at_once)
		if i < links.size():
			exact += ICON + GAP + links[i] + GAP
	_place_leaving()
	_place_chip(x + ICON + CHIP_GAP, hidden)
	_place_bus()
	if still:
		_snap()


# Each link's width in pixels, to scale with [param legs] in the room left, each at least
# MIN_LINK and the bus's own, the first, at least MIN_CURRENT_LINK.
func _link_widths(legs: PackedFloat32Array, chip: bool) -> PackedFloat32Array:
	var count := legs.size()
	var room := size.x - (count + 1) * ICON - count * GAP * 2.0
	if chip:
		room -= CHIP_GAP + CHIP_WIDTH
	var widths := PackedFloat32Array()
	widths.resize(count)
	var least := PackedFloat32Array()
	for i: int in count:
		least.append(MIN_CURRENT_LINK if i == 0 else MIN_LINK)
	# Links that would come out too short take their least; the rest share what is left.
	var fixed: Array[int] = []
	for _pass: int in count + 1:
		var free_room := room
		var free_length := 0.0
		var free_count := 0
		for i: int in count:
			if i in fixed:
				free_room -= widths[i]
			else:
				free_length += maxf(legs[i], 0.0)
				free_count += 1
		var settled := true
		for i: int in count:
			if i in fixed:
				continue
			var share := maxf(legs[i], 0.0) / free_length if free_length > 0.0 else 1.0 / free_count
			widths[i] = free_room * share
			if widths[i] < least[i]:
				widths[i] = least[i]
				fixed.append(i)
				settled = false
		if settled:
			break
	return widths


func _enter(stop: RouteStop, x: float, at_once: bool) -> void:
	var icon := _make_icon(stop)
	var slide := 0.0 if at_once or Settings.reduce_motion else ENTER_SLIDE
	icon.position = Vector2(x + slide, 0.0)
	add_child(icon)
	move_child(icon, _chip.get_index())
	_icons[stop] = icon
	if at_once:
		return
	icon.modulate.a = 0.0
	if not Settings.reduce_motion:
		icon.scale = Vector2.ONE * ENTER_SCALE
	var fade := icon.create_tween().set_parallel().set_trans(Tween.TRANS_QUART)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(icon, ^"modulate:a", 1.0, ENTER_SECONDS)
	fade.tween_property(icon, ^"scale", Vector2.ONE, ENTER_SECONDS)
	_fades[stop] = fade


func _leave(stop: RouteStop, at_once: bool) -> void:
	var icon := _icons[stop] as Control
	if _fades.has(stop):
		(_fades[stop] as Tween).kill()
	if at_once:
		_forget(stop)
		return
	_leaving[stop] = true
	var fade := icon.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(icon, ^"modulate:a", 0.0, EXIT_SECONDS)
	if not Settings.reduce_motion:
		fade.tween_property(icon, ^"scale", Vector2.ONE * ENTER_SCALE, EXIT_SECONDS)
	fade.chain().tween_callback(_forget.bind(stop))
	_fades[stop] = fade


# A stop going that is shown again, as when a fold pushes the last one out and back,
# turns round from where its fade got to instead of blinking out and coming in again.
func _come_back(stop: RouteStop, at_once: bool) -> void:
	var icon := _icons[stop] as Control
	(_fades[stop] as Tween).kill()
	_leaving.erase(stop)
	if at_once:
		icon.modulate.a = 1.0
		icon.scale = Vector2.ONE
		_fades.erase(stop)
		return
	var fade := icon.create_tween().set_parallel().set_trans(Tween.TRANS_QUART)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(icon, ^"modulate:a", 1.0, ENTER_SECONDS)
	fade.tween_property(icon, ^"scale", Vector2.ONE, ENTER_SECONDS)
	_fades[stop] = fade


func _forget(stop: RouteStop) -> void:
	_badges.erase(_icons[stop])
	(_icons[stop] as Control).queue_free()
	_icons.erase(stop)
	_targets.erase(stop)
	_fades.erase(stop)
	_leaving.erase(stop)
	_order.erase(stop)
	if _hovered and not is_instance_valid(_hovered):
		_hovered = null


# [param shown] in order, with every icon still going from [param old] kept after the one
# it followed.
func _merged(old: Array[RouteStop], shown: Array[RouteStop]) -> Array[RouteStop]:
	var merged := shown.duplicate()
	var after: RouteStop = null
	for stop: RouteStop in old:
		if not merged.has(stop):
			if not _icons.has(stop):
				continue
			merged.insert(merged.find(after) + 1 if after else 0, stop)
		after = stop
	return merged


# An icon going before the start folds away to the left; any other fades where it is.
func _place_leaving() -> void:
	var start := _order.find(_shown[0]) if not _shown.is_empty() else _order.size()
	for i: int in start:
		_targets[_order[i]] = -ICON - GAP * 2.0 - (start - 1 - i) * ICON


func _place_chip(x: float, hidden: int) -> void:
	if hidden > 0 and not _chip.visible:
		_chip.position.x = x
	_chip.visible = hidden > 0
	if _chip_text != "+%d" % hidden:
		_chip_text = "+%d" % hidden
		_chip.queue_redraw()
	_chip_target = x


# The bus waits just past the start, or flies the first link toward the next stop.
func _place_bus() -> void:
	_bus.visible = not _shown.is_empty()
	if _shown.is_empty():
		return
	var start: float = _targets[_shown[0]] + ICON + WAIT_OFFSET
	if _progress < 0.0 or _shown.size() < 2:
		_bus_target = start
	else:
		var last := _shown.size() == 2 and not _chip.visible
		var end: float = _targets[_shown[1]] - (END_OFFSET if last else DOCK_OFFSET)
		_bus_target = lerpf(start, end, _progress)


func _snap() -> void:
	for stop: RouteStop in _icons:
		(_icons[stop] as Control).position.x = _targets[stop]
	_bus_x = _bus_target
	_chip.position.x = _chip_target


func _make_icon(stop: RouteStop) -> Control:
	var icon := Control.new()
	icon.size = Vector2.ONE * ICON
	icon.pivot_offset = icon.size * 0.5
	# It takes the pointer for its tooltip and passes it on.
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	if stop.planet:
		var planet := PlanetIcon.new()
		planet.size = icon.size
		planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		planet.planet = stop.planet
		icon.add_child(planet)
	else:
		var point := TextureRect.new()
		point.texture = POINT_TEXTURE
		point.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		point.size = Vector2.ONE * POINT_ICON
		point.position = (icon.size - point.size) * 0.5
		point.self_modulate = POINT_COLOR
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(point)
	var tooltip := TOOLTIP.instantiate() as Tooltip
	tooltip.target = icon
	tooltip.title = _stop_name(stop)
	tooltip.side = Tooltip.Side.ABOVE
	icon.add_child(tooltip)
	var badge := RemoveBadge.new()
	badge.visible = false
	icon.add_child(badge)
	badge.position = (
		(Vector2(ICON, 0.0) + BADGE_OFFSET - Vector2.ONE * RemoveBadge.SIZE * 0.5).round()
	)
	badge.pressed.connect(_on_badge_pressed.bind(stop))
	_badges[icon] = badge
	icon.mouse_entered.connect(_hover.bind(icon))
	icon.mouse_exited.connect(_unhover.bind(icon))
	badge.mouse_exited.connect(_unhover.bind(icon))
	icon.draw.connect(_draw_hover.bind(icon))
	return icon


func _on_badge_pressed(stop: RouteStop) -> void:
	_badge_of(_icons[stop] as Control).visible = false
	remove_pressed.emit(stop)


func _badge_of(icon: Control) -> RemoveBadge:
	return _badges[icon] as RemoveBadge


func _hover(icon: Control) -> void:
	var was := _hovered
	_hovered = icon
	for each: Control in [was, icon]:
		if each and is_instance_valid(each):
			each.queue_redraw()
			_badge_of(each).visible = each == icon and _removable(each)


# The pointer left [param icon] or its X. Once the viewport has settled which control is
# under it, nothing is hovered unless that is the icon or the X poking out of its corner.
func _unhover(icon: Control) -> void:
	_settle_hover.call_deferred(icon)


func _settle_hover(icon: Control) -> void:
	if not is_inside_tree() or not is_instance_valid(icon) or _hovered != icon:
		return
	var over := get_viewport().gui_get_hovered_control()
	if over and (over == icon or icon.is_ancestor_of(over)):
		return
	_hover(null)


# Whether [param icon] offers the X: its stop isn't where the line starts or going, and
# can_remove allows it.
func _removable(icon: Control) -> bool:
	var stop: RouteStop = _icons.find_key(icon)
	if not stop or _leaving.has(stop) or (not _shown.is_empty() and _shown[0] == stop):
		return false
	return can_remove.is_valid() and can_remove.call(stop)


func _stop_name(stop: RouteStop) -> String:
	if not stop.planet:
		return "Point in space"
	return stop.planet.display_name if stop.planet.display_name else String(stop.planet.name)


# The links between icons: the one the bus is on orange up to it, and those folding away
# before the start orange too, as flown.
func _draw() -> void:
	var start := _order.find(_shown[0]) if not _shown.is_empty() else -1
	var y := ICON * 0.5 - 1.0
	for i: int in _order.size() - 1:
		var from := _icons[_order[i]] as Control
		var to := _icons[_order[i + 1]] as Control
		var left := from.position.x + ICON + GAP
		var right := to.position.x - GAP
		if right <= left:
			continue
		var alpha := minf(from.modulate.a, to.modulate.a)
		var flown := i < start
		var split := left
		if i == start and _progress >= 0.0:
			split = clampf(_bus_x, left, right)
		if flown:
			split = right
		_draw_link(left, split, y, Color(FLOWN_COLOR, alpha))
		_draw_link(split, right, y, Color(AHEAD_COLOR, AHEAD_COLOR.a * alpha))


# A piece of link, less the bus's room, dropping slivers too short to read beside it.
func _draw_link(left: float, right: float, y: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	var pieces: Array[Vector2] = [Vector2(left, right)]
	if _bus.visible:
		pieces = [Vector2(left, minf(right, _bus_x - BUS_ROOM))]
		pieces.append(Vector2(maxf(left, _bus_x + BUS_ROOM), right))
	for piece: Vector2 in pieces:
		var length := piece.y - piece.x
		if length >= SHORTEST_PIECE or (length > 0.5 and not _bus.visible):
			draw_rect(Rect2(piece.x, y, length, 2.0), color)


# Cuts the bus's room out of each planet it overlaps, in the icon's own pixels, as it
# grows and shrinks round its middle.
func _cut_planets() -> void:
	for stop: RouteStop in _icons:
		var icon := _icons[stop] as Control
		var planet := icon.get_child(0) as PlanetIcon
		if not planet:
			continue
		var bus := Vector2(_bus_x, ICON * 0.5) - icon.position - icon.pivot_offset
		var scale_x := maxf(icon.scale.x, 0.01)
		var radius := BUS_ROOM / scale_x if _bus.visible else 0.0
		planet.cut(bus / scale_x + icon.pivot_offset, radius)


func _draw_bus() -> void:
	var middle := _bus.size * 0.5
	var rect := Rect2(middle - Vector2.ONE * BUS_ICON * 0.5, Vector2.ONE * BUS_ICON)
	_bus.draw_texture_rect(BUS_TEXTURE, rect, false, BUS_COLOR)


func _draw_hover(icon: Control) -> void:
	if icon == _hovered:
		icon.draw_arc(icon.size * 0.5, ICON * 0.5 + 1.5, 0.0, TAU, 32, HOVER_COLOR, 1.0, true)


# A pill as tall as a planet's disc, centred on the line, with how many stops the line
# leaves out.
func _draw_chip() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = CHIP_COLOR
	box.set_corner_radius_all(int(CHIP_HEIGHT * 0.5))
	box.anti_aliasing = true
	var top := (ICON - CHIP_HEIGHT) * 0.5
	_chip.draw_style_box(box, Rect2(0.0, top, CHIP_WIDTH, CHIP_HEIGHT))
	var font := get_theme_font(&"font", &"SmallStrongLabel")
	# Centred on the digits' own height, about the ascent's lower part in Baloo 2, not on
	# the font's tall line.
	var ink := font.get_ascent(CHIP_FONT_SIZE) * 0.72
	var baseline := Vector2(0.0, roundf(ICON * 0.5 + ink * 0.5))
	_chip.draw_string(
		font,
		baseline,
		_chip_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		CHIP_WIDTH,
		CHIP_FONT_SIZE,
		POINT_COLOR
	)
