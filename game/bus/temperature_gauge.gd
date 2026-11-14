class_name TemperatureGauge
extends Control
## The bus's temperature as a bar from [member minimum] to [member maximum] degrees: a faint
## track with the comfortable band on it, and a marker at [member degrees] that stands
## proud of the track above and below.

const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.14)
const BAND_COLOR := Color(0.549, 0.851, 0.4, 0.4)
const MARKER_COLOR := Color(0.957, 0.945, 1.0, 1.0)
const TRACK_HEIGHT := 5.0
const MARKER_WIDTH := 3.0
const CORNER := 2.0

## Degrees at the bar's left end. Room for cold, which nothing makes yet.
@export var minimum := -20.0
## Degrees at the bar's right end, where the bus overheats.
@export var maximum := 60.0
## The comfortable band, in degrees.
@export var band_low := 8.0
@export var band_high := 32.0

## The temperature the marker shows.
var degrees := 21.0:
	set(value):
		if value != degrees:
			degrees = value
			queue_redraw()


func _draw() -> void:
	var top := (size.y - TRACK_HEIGHT) * 0.5
	_draw_bar(Rect2(0.0, top, size.x, TRACK_HEIGHT), TRACK_COLOR)
	var low := _x_at(band_low)
	_draw_bar(Rect2(low, top, _x_at(band_high) - low, TRACK_HEIGHT), BAND_COLOR)
	var x := clampf(_x_at(degrees) - MARKER_WIDTH * 0.5, 0.0, size.x - MARKER_WIDTH)
	_draw_bar(Rect2(x, 0.0, MARKER_WIDTH, size.y), MARKER_COLOR)


func _x_at(value: float) -> float:
	return clampf(inverse_lerp(minimum, maximum, value), 0.0, 1.0) * size.x


func _draw_bar(rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(CORNER))
	draw_style_box(box, rect)
