class_name ServeMinigamePrototype
extends Control
## PROTOTYPE, throwaway: minigames to try in the serve button's place of the hold, picked
## from the debug panel's "Serve game" card. It answers one question, which of these feels
## best under hurry, and goes once that is decided. It covers the [ServeButton], which
## hands it the pointer's events ([method handle]) and how far the request is served
## ([member progress]); it draws the game over the button and says how much each move
## serves with [signal fed]. In [constant Mode.HOLD] it does nothing, and the button works
## as it always has. Nothing here follows Reduce motion yet.

## The player's move served [param amount] more of the request, as a fraction of all of it.
signal fed(amount: float)

enum Mode { HOLD, POUR, TIMING, SLIDE, SCRUB, MASH, CATCH, TRACK, ORDER, BY_NEED }

## What each mode is called on the debug panel, and how it is played.
const NAMES: Dictionary[Mode, String] = {
	Mode.HOLD: "Hold",
	Mode.POUR: "Pour",
	Mode.TIMING: "Timing",
	Mode.SLIDE: "Slide",
	Mode.SCRUB: "Scrub",
	Mode.MASH: "Mash",
	Mode.CATCH: "Catch",
	Mode.TRACK: "Track",
	Mode.ORDER: "Order",
	Mode.BY_NEED: "By need",
}
const HINTS: Dictionary[Mode, String] = {
	Mode.HOLD: "Hold the button, as now.",
	Mode.POUR: "Hold to pour, let go past the line. Overflow and the pour is lost.",
	Mode.TIMING: "Click as the marker crosses the zone.",
	Mode.SLIDE: "Drag the knob to the right end.",
	Mode.SCRUB: "Hold and rub left and right.",
	Mode.MASH: "Click five times.",
	Mode.CATCH: "Click the chip three times, wherever it jumps.",
	Mode.TRACK: "Hold with the pointer inside the drifting zone.",
	Mode.ORDER: "Click 1, 2, 3, 4 in order. A wrong one starts over and shuffles them.",
	Mode.BY_NEED: "A snack is a slide, a drink is a pour.",
}

## Pour: seconds from empty to overflowing, and where the line is. Let go between the line
## and the brim to serve it all.
const POUR_SECONDS := 1.1
const POUR_LINE := 0.8
## Timing: seconds for the marker to cross once, the zone's width and the near miss's
## margin each side, as shares of the button, and what a near miss and a miss serve.
const SWEEP_SECONDS := 0.8
const ZONE_WIDTH := 0.2
const NEAR_MARGIN := 0.1
const NEAR_FEED := 0.5
const MISS_FEED := 0.15
## Slide: the knob's width in pixels, how far outside it a press still grabs it, and from
## how far along the drag counts as all the way.
const KNOB_WIDTH := 24.0
const GRAB_SLACK := 10.0
const SLIDE_DONE := 0.95
## Scrub: how many button widths of rubbing serve a request.
const SCRUB_WIDTHS := 2.5
## Mash and Catch: clicks to serve a request.
const MASH_CLICKS := 5
const CATCH_CLICKS := 3
## Catch: the chip's width in pixels, how far outside it a click still counts, and how far
## it jumps at least, as a share of the button.
const CHIP_WIDTH := 22.0
const CHIP_SLACK := 4.0
const CHIP_JUMP := 0.3
## Track: the zone's width as a share of the button, the seconds it takes to drift there
## and back, and the seconds inside it that serve a request.
const TRACK_WIDTH := 0.3
const TRACK_PERIOD := 2.2
const TRACK_SECONDS := 1.0

## Order: how many buttons there are to press in order.
const ORDER_BUTTONS := 4

const FLASH_SECONDS := 0.25
const GOOD := Color(0.6, 1.0, 0.7)
const BAD := Color(1.0, 0.45, 0.45)
const CYAN := Color(0.6, 0.949, 1.0)
const DARK := Color(0.1059, 0.0902, 0.251)
const RADIUS := 6

## The game every serve button plays.
static var mode := Mode.HOLD

## How much of the request is served, from 0 to 1. The button sets it.
var progress := 0.0
## The request's label, which decides the game in [constant Mode.BY_NEED].
var request_label := ""

var _running := Mode.HOLD
var _pressed := false
var _pointer_x := 0.0
var _clock := 0.0
# Pour: how full the glass is. Slide: how far the knob is. Both from 0 to 1.
var _level := 0.0
var _grabbed := false
# Timing: where the zone starts. Catch: where the chip starts. Shares of the button.
var _spot := 0.5
var _phase := 0.0
# Order: the number on each button, left to right, and the number to press next.
var _numbers: Array[int] = []
var _next := 1
var _flash := 0.0
var _flash_color := GOOD
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_restart()


func _notification(what: int) -> void:
	# A new request starts the game afresh, and a press never outlives the button.
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_restart()


func _process(delta: float) -> void:
	var game := get_game()
	if game != _running:
		_running = game
		_restart()
	if game == Mode.HOLD:
		return
	_clock += delta
	_flash = maxf(_flash - delta / FLASH_SECONDS, 0.0)
	match game:
		Mode.POUR:
			if _pressed:
				_level = minf(_level + delta / POUR_SECONDS, 1.0)
				if _level >= 1.0:
					_pressed = false
					_flash_with(BAD)
			else:
				_level = progress
		Mode.SLIDE:
			_level = maxf(_level, progress) if _grabbed else progress
		Mode.TRACK:
			if _pressed and _in_track_zone():
				fed.emit(delta / TRACK_SECONDS)
	queue_redraw()


## The game played now: [member mode], or in [constant Mode.BY_NEED] the request's own.
func get_game() -> Mode:
	if mode != Mode.BY_NEED:
		return mode
	return Mode.POUR if request_label.containsn("drink") else Mode.SLIDE


## Whether a game takes the hold's place, so the button's own hold must serve nothing.
func is_playing() -> bool:
	return get_game() != Mode.HOLD


## How opaque the button's label is under the game, so the game reads over it.
func get_label_alpha() -> float:
	match get_game():
		Mode.TIMING, Mode.TRACK:
			return 0.5
		Mode.SLIDE:
			return 0.6
		Mode.CATCH, Mode.ORDER:
			return 0.0
	return 1.0


## Takes one of the button's pointer events: a press, a release or a move.
func handle(event: InputEvent) -> void:
	if not is_playing():
		return
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		_pointer_x = click.position.x
		if click.pressed:
			_pressed = true
			_press()
		elif _pressed:
			_pressed = false
			_let_go()
	elif motion:
		var from := _pointer_x
		_pointer_x = motion.position.x
		if _pressed:
			_drag(from)


func _restart() -> void:
	_pressed = false
	_grabbed = false
	_level = progress
	_clock = 0.0
	_flash = 0.0
	_phase = randf() * TAU
	_shuffle()
	_spot = randf_range(0.35, 1.0 - ZONE_WIDTH) if get_game() == Mode.TIMING else randf() * 0.8
	queue_redraw()


func _press() -> void:
	match get_game():
		Mode.POUR:
			_level = progress
		Mode.TIMING:
			var marker := pingpong(_clock / SWEEP_SECONDS, 1.0)
			if marker >= _spot and marker <= _spot + ZONE_WIDTH:
				_flash_with(GOOD)
				fed.emit(1.0)
			elif marker >= _spot - NEAR_MARGIN and marker <= _spot + ZONE_WIDTH + NEAR_MARGIN:
				_flash_with(CYAN)
				fed.emit(NEAR_FEED)
			else:
				_flash_with(BAD)
				fed.emit(MISS_FEED)
		Mode.SLIDE:
			var knob := _level * (size.x - KNOB_WIDTH)
			_grabbed = (
				_pointer_x >= knob - GRAB_SLACK and _pointer_x <= knob + KNOB_WIDTH + GRAB_SLACK
			)
		Mode.MASH:
			_flash_with(CYAN)
			fed.emit(1.0 / MASH_CLICKS)
		Mode.CATCH:
			var chip := _spot * (size.x - CHIP_WIDTH)
			if _pointer_x >= chip - CHIP_SLACK and _pointer_x <= chip + CHIP_WIDTH + CHIP_SLACK:
				_flash_with(GOOD)
				var next := randf()
				while absf(next - _spot) < CHIP_JUMP:
					next = randf()
				_spot = next
				fed.emit(1.0 / CATCH_CLICKS)
			else:
				_flash_with(BAD)
		Mode.ORDER:
			var button := clampi(
				int(_pointer_x / maxf(size.x, 1.0) * ORDER_BUTTONS), 0, ORDER_BUTTONS - 1
			)
			if _numbers[button] == _next:
				_next += 1
				if _next > ORDER_BUTTONS:
					_flash_with(GOOD)
					_shuffle()
					fed.emit(1.0)
			elif _numbers[button] > _next:
				_flash_with(BAD)
				_shuffle()


func _let_go() -> void:
	match get_game():
		Mode.POUR:
			if _level >= POUR_LINE:
				_flash_with(GOOD)
				fed.emit(1.0)
			elif _level > progress:
				fed.emit(_level - progress)
		Mode.SLIDE:
			_grabbed = false


func _drag(from: float) -> void:
	match get_game():
		Mode.SLIDE:
			if not _grabbed:
				return
			var to := clampf(
				(_pointer_x - KNOB_WIDTH / 2.0) / maxf(size.x - KNOB_WIDTH, 1.0), 0.0, 1.0
			)
			if to >= SLIDE_DONE:
				to = 1.0
				_flash_with(GOOD)
			if to > _level:
				fed.emit(to - _level)
				_level = to
		Mode.SCRUB:
			fed.emit(absf(_pointer_x - from) / (maxf(size.x, 1.0) * SCRUB_WIDTHS))


# Order: numbers the buttons afresh, in a new order, with none pressed.
func _shuffle() -> void:
	_numbers.assign(range(1, ORDER_BUTTONS + 1))
	_numbers.shuffle()
	_next = 1


func _in_track_zone() -> bool:
	var start := _track_start() * size.x
	return _pointer_x >= start and _pointer_x <= start + TRACK_WIDTH * size.x


func _track_start() -> float:
	var swing := 0.5 + 0.5 * sin(_clock * TAU / TRACK_PERIOD + _phase)
	return swing * (1.0 - TRACK_WIDTH)


func _flash_with(color: Color) -> void:
	_flash = 1.0
	_flash_color = color


func _draw() -> void:
	var game := get_game()
	if game == Mode.HOLD:
		return
	var w := size.x
	var h := size.y
	match game:
		Mode.POUR:
			_draw_box(Rect2(POUR_LINE * w, 0.0, (1.0 - POUR_LINE) * w, h), Color(1, 1, 1, 0.16))
			draw_rect(Rect2(POUR_LINE * w, 0.0, 1.0, h), Color(1, 1, 1, 0.7))
			if _pressed and _level > progress:
				var poured := Rect2(progress * w, 0.0, (_level - progress) * w, h)
				_draw_box(poured, Color(CYAN, 0.55))
		Mode.TIMING:
			var near := Rect2(
				(_spot - NEAR_MARGIN) * w, 0.0, (ZONE_WIDTH + 2.0 * NEAR_MARGIN) * w, h
			)
			_draw_box(near, Color(1, 1, 1, 0.1))
			_draw_box(Rect2(_spot * w, 0.0, ZONE_WIDTH * w, h), Color(1, 1, 1, 0.3))
			var marker := pingpong(_clock / SWEEP_SECONDS, 1.0) * (w - 2.0)
			draw_rect(Rect2(marker, 0.0, 2.0, h), Color.WHITE)
		Mode.SLIDE:
			_draw_box(Rect2(w - KNOB_WIDTH, 0.0, KNOB_WIDTH, h), Color(1, 1, 1, 0.14))
			var knob := Rect2(_level * (w - KNOB_WIDTH), 0.0, KNOB_WIDTH, h)
			_draw_box(knob, Color(1, 1, 1, 0.95 if _grabbed else 0.8))
			for chevron: int in 2:
				var x := knob.position.x + 8.0 + chevron * 5.0
				var points := PackedVector2Array(
					[Vector2(x, 5.0), Vector2(x + 4.0, h / 2.0), Vector2(x, h - 5.0)]
				)
				draw_polyline(points, DARK, 1.5, true)
		Mode.SCRUB:
			for side: int in 2:
				var x := 8.0 if side == 0 else w - 8.0
				var tip := -4.0 if side == 0 else 4.0
				var points := PackedVector2Array(
					[Vector2(x, 5.0), Vector2(x + tip, h / 2.0), Vector2(x, h - 5.0)]
				)
				draw_polyline(points, Color(1, 1, 1, 0.6), 1.5, true)
		Mode.MASH:
			for pip: int in range(1, MASH_CLICKS):
				draw_rect(Rect2(w * pip / MASH_CLICKS, 3.0, 1.0, h - 6.0), Color(1, 1, 1, 0.35))
		Mode.CATCH:
			var chip := Rect2(_spot * (w - CHIP_WIDTH), 2.0, CHIP_WIDTH, h - 4.0)
			_draw_box(chip, Color(1, 1, 1, 0.9))
		Mode.TRACK:
			var inside := _pressed and _in_track_zone()
			var zone := Rect2(_track_start() * w, 0.0, TRACK_WIDTH * w, h)
			_draw_box(zone, Color(CYAN, 0.5) if inside else Color(1, 1, 1, 0.22))
		Mode.ORDER:
			var font := get_theme_font(&"font", &"SmallStrongLabel")
			var font_size := get_theme_font_size(&"font_size", &"SmallStrongLabel")
			var each := w / ORDER_BUTTONS
			for button: int in ORDER_BUTTONS:
				var done := _numbers[button] < _next
				var box := Rect2(button * each + 1.0, 0.0, each - 2.0, h)
				_draw_box(box, Color(CYAN, 0.45) if done else Color(1, 1, 1, 0.22))
				var baseline := Vector2(box.position.x, h / 2.0 + font_size * 0.36)
				var color := Color(1, 1, 1, 0.45 if done else 1.0)
				draw_string(
					font,
					baseline,
					str(_numbers[button]),
					HORIZONTAL_ALIGNMENT_CENTER,
					box.size.x,
					font_size,
					color
				)
	if _flash > 0.0:
		_draw_box(Rect2(Vector2.ZERO, size), Color(_flash_color, 0.45 * _flash))


func _draw_box(rect: Rect2, color: Color) -> void:
	_box.bg_color = color
	_box.set_corner_radius_all(mini(RADIUS, int(rect.size.x / 2.0)))
	draw_style_box(_box, rect)
