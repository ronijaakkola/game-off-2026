class_name MorphLabel
extends Label
## A Label that morphs into new text instead of swapping it. A wave sweeps left to right:
## the old letters drift up and smear away, and the new ones rise into place and come into
## focus just behind it, so each spot clears before its new letter lands. Letters both
## texts start with stay, sliding to their new place when the alignment moves them.
## Change the text with [method morph_to]; setting [member Label.text] still swaps it at
## once. With Reduce motion on, it swaps too.
## While it morphs, [member Label.text] is already the new text, so layout and readers see
## it. The label's own drawing is hidden by [member CanvasItem.self_modulate], and the
## letters are drawn on a canvas item of its own, beneath it in the tree, so they keep the
## label's clipping and modulate.

# Where the smeared copies of a letter go, times the smear.
const SMEAR_TAPS: Array[Vector2] = [
	Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -0.6), Vector2(0.0, 0.6)
]

## Seconds a letter takes to leave.
@export var leave_seconds := 0.12
## Seconds a letter takes to arrive.
@export var arrive_seconds := 0.24
## Seconds the wave takes to cross half an em, about one letter.
@export var stagger_seconds := 0.016
## Seconds after the wave reaches a spot that letters start arriving there.
@export var arrive_delay := 0.08
## How far a letter drifts, in ems: up as it leaves, and up from below as it arrives.
@export var drift := 0.2
## How far a letter smears at its blurriest, in ems.
@export var smear := 0.12

# The text morphing away and the text arriving, each trimmed to fit as the label shows it,
# and the old text's colour.
var _from := ""
var _to := ""
var _from_color := Color.WHITE
# Each text's shaped glyphs, as the label draws them (_glyphs()), and its line's width.
var _from_glyphs: Array[Dictionary] = []
var _to_glyphs: Array[Dictionary] = []
var _from_width := 0.0
var _to_width := 0.0
# How many letters both texts start with.
var _kept := 0
var _time := 0.0
# Seconds the whole morph takes; 0 while not morphing.
var _duration := 0.0
# The canvas item the morph draws on, and the label's self modulate to give back after.
var _canvas: RID
var _self_modulate := Color.WHITE


func _ready() -> void:
	set_process(false)
	_canvas = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas, get_canvas_item())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _canvas.is_valid():
		RenderingServer.free_rid(_canvas)
	# Layout can narrow the label in the frame after the text changes, as when the serve
	# button appears beside it, so the arriving text is trimmed again to the new width.
	if what == NOTIFICATION_RESIZED and is_morphing():
		_shape_to(text)
		_kept = mini(_kept, _shared_start(_from, _to))
		_draw_morph()


func _process(delta: float) -> void:
	_time += delta
	if _time >= _duration:
		_stop()
	else:
		_draw_morph()


## Morphs from the current text to [param new_text]. A morph already running restarts from
## the text it was heading to. From an empty text, while hidden or with Reduce motion on,
## the text swaps at once.
func morph_to(new_text: String) -> void:
	if new_text == text:
		return
	if text.is_empty() or not is_visible_in_tree() or Settings.reduce_motion:
		_stop()
		text = new_text
		return
	var from_line := _shape(text)
	_from = _shown_text(text, from_line)
	_from_glyphs = _glyphs(from_line, _from.length() - 1)
	_from_width = _width(_from_glyphs)
	_from_color = get_theme_color(&"font_color")
	_shape_to(new_text)
	_kept = _shared_start(_from, _to)
	text = new_text
	_time = 0.0
	var widest := maxf(_from_width, _to_width)
	_duration = arrive_delay + _wave_delay(widest, get_theme_font_size(&"font_size"))
	_duration += arrive_seconds
	if self_modulate.a > 0.0:
		_self_modulate = self_modulate
	self_modulate = Color(_self_modulate, 0.0)
	set_process(true)
	_draw_morph()


## Whether a morph is running.
func is_morphing() -> bool:
	return _duration > 0.0


func _stop() -> void:
	_duration = 0.0
	_from = ""
	_to = ""
	_from_glyphs.clear()
	_to_glyphs.clear()
	if _canvas.is_valid():
		RenderingServer.canvas_item_clear(_canvas)
	if self_modulate.a == 0.0:
		self_modulate = _self_modulate
	set_process(false)


func _shape_to(line: String) -> void:
	var shaped := _shape(line)
	_to = _shown_text(line, shaped)
	_to_glyphs = _glyphs(shaped, _to.length() - 1)
	_to_width = _width(_to_glyphs)


func _draw_morph() -> void:
	RenderingServer.canvas_item_clear(_canvas)
	var font_size := get_theme_font_size(&"font_size")
	var color := get_theme_color(&"font_color")
	var baseline := _baseline()
	var drift_px := drift * font_size
	var smear_px := smear * font_size
	var from_left := _left(_from_width)
	var to_left := _left(_to_width)
	var settle := _ease(clampf(_time / arrive_seconds, 0.0, 1.0))
	# The wave starts at the first letter that changes, in either text.
	var wave_from := INF
	for glyph: Dictionary in _from_glyphs:
		if glyph.letter >= _kept:
			wave_from = minf(wave_from, from_left + glyph.x)
			break
	for glyph: Dictionary in _to_glyphs:
		if glyph.letter >= _kept:
			wave_from = minf(wave_from, to_left + glyph.x)
			break
	# Kept letters slide from where the old text had them; both texts shape them alike.
	var kept_shift := (from_left - to_left) * (1.0 - settle)
	for glyph: Dictionary in _to_glyphs:
		var x: float = to_left + glyph.x
		if glyph.letter < _kept:
			_draw_glyph(glyph, Vector2(x + kept_shift, baseline), color, 0.0)
			continue
		var shown := _ease(
			_progress(arrive_delay + _wave_delay(x - wave_from, font_size), arrive_seconds)
		)
		var arriving := Color(color, color.a * shown)
		var at := Vector2(x, baseline + drift_px * (1.0 - shown))
		_draw_glyph(glyph, at, arriving, smear_px * (1.0 - shown))
	for glyph: Dictionary in _from_glyphs:
		if glyph.letter < _kept:
			continue
		var x: float = from_left + glyph.x
		var gone := _ease(_progress(_wave_delay(x - wave_from, font_size), leave_seconds))
		var leaving := Color(_from_color, _from_color.a * (1.0 - gone))
		_draw_glyph(glyph, Vector2(x, baseline - drift_px * gone), leaving, smear_px * gone)


# How many letters [param a] and [param b] start with.
func _shared_start(a: String, b: String) -> int:
	var count := 0
	while count < mini(a.length(), b.length()) and a[count] == b[count]:
		count += 1
	return count


# How far a change that starts at [param start] and takes [param seconds] is, 0 to 1.
func _progress(start: float, seconds: float) -> float:
	return clampf((_time - start) / seconds, 0.0, 1.0)


# Seconds the wave takes to travel [param distance] pixels at [param font_size].
func _wave_delay(distance: float, font_size: int) -> float:
	return maxf(distance, 0.0) / (font_size * 0.5) * stagger_seconds


# A cubic ease out: quick to start, soft to land.
func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


# A glyph with its baseline at [param at], sharp at no blur, otherwise a faint copy at its
# place and around it.
func _draw_glyph(glyph: Dictionary, at: Vector2, color: Color, blur: float) -> void:
	if color.a <= 0.004:
		return
	if blur < 0.25:
		_draw_glyph_at(glyph, at, color)
		return
	_draw_glyph_at(glyph, at, Color(color, color.a * 0.5))
	var tap := Color(color, color.a * 0.3)
	for direction: Vector2 in SMEAR_TAPS:
		_draw_glyph_at(glyph, at + direction * blur, tap)


func _draw_glyph_at(glyph: Dictionary, at: Vector2, color: Color) -> void:
	var server := TextServerManager.get_primary_interface()
	var position: Vector2 = at + glyph.offset
	server.font_draw_glyph(glyph.font_rid, _canvas, glyph.font_size, position, glyph.index, color)


# [param line] shaped with the label's font, width and overrun, as the label shapes it.
func _shape(line: String) -> TextLine:
	var shaped := TextLine.new()
	shaped.add_string(line, get_theme_font(&"font"), get_theme_font_size(&"font_size"))
	if clip_text and text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		var style := get_theme_stylebox(&"normal")
		shaped.width = size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		shaped.ellipsis_char = ellipsis_char
		shaped.text_overrun_behavior = text_overrun_behavior
	return shaped


# The letters [param shaped] shows: [param line], cut short with the ellipsis where the
# text server trims it. Word trimming is compared as letter trimming.
func _shown_text(line: String, shaped: TextLine) -> String:
	var trim := _trim(shaped)
	if trim < 0 or trim >= line.length():
		return line
	return line.left(trim) + ellipsis_char


func _trim(shaped: TextLine) -> int:
	shaped.get_size()  # Shapes and trims the line, which is lazy.
	return TextServerManager.get_primary_interface().shaped_text_get_trim_pos(shaped.get_rid())


# The glyphs [param shaped] draws, in order, each a dictionary of the text server's glyph
# with its pen x from the line's start and the letter it belongs to. Glyphs past the trim
# are dropped and the ellipsis glyphs follow, as letter [param ellipsis_letter].
func _glyphs(shaped: TextLine, ellipsis_letter: int) -> Array[Dictionary]:
	var server := TextServerManager.get_primary_interface()
	var rid := shaped.get_rid()
	var trim := _trim(shaped)
	var result: Array[Dictionary] = []
	var x := 0.0
	for glyph: Dictionary in server.shaped_text_get_glyphs(rid):
		if trim >= 0 and int(glyph.start) >= trim:
			break
		x = _add_glyph(result, glyph, x, glyph.start)
	if trim >= 0:
		for glyph: Dictionary in server.shaped_text_get_ellipsis_glyphs(rid):
			x = _add_glyph(result, glyph, x, ellipsis_letter)
	return result


# Adds [param glyph], repeated as the server asks, at pen [param x]; returns the next x.
func _add_glyph(into: Array[Dictionary], glyph: Dictionary, x: float, letter: int) -> float:
	for repeat: int in maxi(int(glyph.get("repeat", 1)), 1):
		var placed := glyph.duplicate()
		placed.x = x
		placed.letter = letter
		into.append(placed)
		x += float(glyph.advance)
	return x


func _width(glyphs: Array[Dictionary]) -> float:
	if glyphs.is_empty():
		return 0.0
	var last: Dictionary = glyphs.back()
	return float(last.x) + float(last.advance)


# Where a line [param width] wide starts, by the horizontal alignment inside the stylebox.
func _left(width: float) -> float:
	var style := get_theme_stylebox(&"normal")
	var left := style.get_margin(SIDE_LEFT)
	var room := size.x - left - style.get_margin(SIDE_RIGHT)
	# Whole pixels, as Label places them, so the hand-off back to it doesn't shift.
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return left + int(room - width) / 2
		HORIZONTAL_ALIGNMENT_RIGHT:
			return left + int(room - width)
	return left


# The baseline of the one line, by the vertical alignment inside the stylebox.
func _baseline() -> float:
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var style := get_theme_stylebox(&"normal")
	var top := style.get_margin(SIDE_TOP)
	var room := size.y - top - style.get_margin(SIDE_BOTTOM)
	var height := font.get_height(font_size)
	match vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			top += (room - height) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			top += room - height
	return top + font.get_ascent(font_size)
