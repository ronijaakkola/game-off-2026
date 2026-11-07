class_name MorphLabel
extends Label
## A Label that morphs into new text instead of swapping it. A wave sweeps left to right:
## the old letters drift up and smear away, and the new ones rise into place and come into
## focus just behind it, so each spot clears before its new letter lands. Letters both
## texts start with stay, sliding to their new place when the alignment moves them.
## Change the text with [method morph_to]; setting [member Label.text] still swaps it at
## once. With Reduce motion on, it swaps too.
## While it morphs, [member Label.text] is already the new text, so layout and readers see
## it, and the label draws the letters itself.

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
# the old text's colour, and each letter's x from the start of its text.
var _from := ""
var _to := ""
var _from_color := Color.WHITE
var _from_x := PackedFloat32Array()
var _to_x := PackedFloat32Array()
# How many letters both texts start with.
var _kept := 0
var _time := 0.0
# Seconds the whole morph takes; 0 while not morphing.
var _duration := 0.0


func _ready() -> void:
	set_process(false)


func _notification(what: int) -> void:
	# Layout can narrow the label in the frame after the text changes, as when the serve
	# button appears beside it, so the arriving text is trimmed again to the new width.
	if what == NOTIFICATION_RESIZED and is_morphing():
		var font := get_theme_font(&"font")
		var font_size := get_theme_font_size(&"font_size")
		_to = _fitted(text, font, font_size)
		_to_x = _letter_xs(_to, font, font_size)
		_kept = mini(_kept, _shared_start(_from, _to))


func _process(delta: float) -> void:
	_time += delta
	if _time >= _duration:
		_stop()
	queue_redraw()


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
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	_from = _fitted(text, font, font_size)
	_to = _fitted(new_text, font, font_size)
	_from_color = get_theme_color(&"font_color")
	_kept = _shared_start(_from, _to)
	text = new_text
	_from_x = _letter_xs(_from, font, font_size)
	_to_x = _letter_xs(_to, font, font_size)
	var widest := maxf(_text_width(_from, font, font_size), _text_width(_to, font, font_size))
	_time = 0.0
	_duration = arrive_delay + _wave_delay(widest, font_size) + arrive_seconds
	# Shaped as usual, so the size and clipping stay the new text's, but drawn by _draw.
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	visible_characters = 0
	set_process(true)
	queue_redraw()


## Whether a morph is running.
func is_morphing() -> bool:
	return _duration > 0.0


func _stop() -> void:
	_duration = 0.0
	_from = ""
	_to = ""
	visible_characters = -1
	set_process(false)


func _draw() -> void:
	if not is_morphing():
		return
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var color := get_theme_color(&"font_color")
	var baseline := _baseline(font, font_size)
	var drift_px := drift * font_size
	var smear_px := smear * font_size
	var from_left := _left(_from, font, font_size)
	var to_left := _left(_to, font, font_size)
	var settle := _ease(clampf(_time / arrive_seconds, 0.0, 1.0))
	# The wave starts at the first letter that changes, in either text.
	var wave_from := INF
	if _kept < _from.length():
		wave_from = from_left + _from_x[_kept]
	if _kept < _to.length():
		wave_from = minf(wave_from, to_left + _to_x[_kept])
	for i: int in _kept:
		var x := lerpf(from_left + _from_x[i], to_left + _to_x[i], settle)
		_draw_letter(font, font_size, _to[i], Vector2(x, baseline), color, 0.0)
	for i: int in range(_kept, _from.length()):
		var x := from_left + _from_x[i]
		var gone := _ease(_progress(_wave_delay(x - wave_from, font_size), leave_seconds))
		var leaving := Color(_from_color, _from_color.a * (1.0 - gone))
		var at := Vector2(x, baseline - drift_px * gone)
		_draw_letter(font, font_size, _from[i], at, leaving, smear_px * gone)
	for i: int in range(_kept, _to.length()):
		var x := to_left + _to_x[i]
		var shown := _ease(
			_progress(arrive_delay + _wave_delay(x - wave_from, font_size), arrive_seconds)
		)
		var arriving := Color(color, color.a * shown)
		var at := Vector2(x, baseline + drift_px * (1.0 - shown))
		_draw_letter(font, font_size, _to[i], at, arriving, smear_px * (1.0 - shown))


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


func _text_width(line: String, font: Font, font_size: int) -> float:
	return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# A cubic ease out: quick to start, soft to land.
func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


# A letter, sharp at no blur, otherwise a faint copy at its place and around it.
func _draw_letter(
	font: Font, font_size: int, letter: String, at: Vector2, color: Color, blur: float
) -> void:
	if color.a <= 0.004:
		return
	if blur < 0.25:
		draw_char(font, at, letter, font_size, color)
		return
	draw_char(font, at, letter, font_size, Color(color, color.a * 0.5))
	var tap := Color(color, color.a * 0.3)
	for direction: Vector2 in SMEAR_TAPS:
		draw_char(font, at + direction * blur, letter, font_size, tap)


# Each letter's x from the start of [param line], with the kerning of the whole line.
func _letter_xs(line: String, font: Font, font_size: int) -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	xs.resize(line.length())
	for i: int in line.length():
		xs[i] = font.get_string_size(line.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return xs


# [param line] as the label shows it: cut short with the ellipsis where the text server
# trims it, as on the activity line. Word trimming is shown as letter trimming.
func _fitted(line: String, font: Font, font_size: int) -> String:
	if not clip_text or text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		return line
	var style := get_theme_stylebox(&"normal")
	var shaped := TextLine.new()
	shaped.add_string(line, font, font_size)
	shaped.width = size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	shaped.ellipsis_char = ellipsis_char
	shaped.text_overrun_behavior = text_overrun_behavior
	shaped.get_size()  # Shapes and trims the line, which is lazy.
	var trim := TextServerManager.get_primary_interface().shaped_text_get_trim_pos(shaped.get_rid())
	if trim < 0 or trim >= line.length():
		return line
	return line.left(trim) + ellipsis_char


# Where [param line] starts, by the horizontal alignment inside the stylebox.
func _left(line: String, font: Font, font_size: int) -> float:
	var style := get_theme_stylebox(&"normal")
	var left := style.get_margin(SIDE_LEFT)
	var room := size.x - left - style.get_margin(SIDE_RIGHT)
	var width := _text_width(line, font, font_size)
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return left + (room - width) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			return left + room - width
	return left


# The baseline of the one line, by the vertical alignment inside the stylebox.
func _baseline(font: Font, font_size: int) -> float:
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
