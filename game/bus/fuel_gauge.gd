class_name FuelGauge
extends MarginContainer
## The bus bar's fuel gauge: a pump, "Fuel" and the percentage over a pale cyan bar. At
## [constant BusStatusPanel.FUEL_LOW] of a full tank or less, the bar and the percentage
## turn red, the pump gives way to a red warning triangle and a red frame shows round the
## gauge. Once every [constant WAVE_SECONDS] the frame and the bar flash and a red ring
## bursts out of the frame, fading as it spreads. Reduce motion keeps the frame and drops
## the flash and the rings.

const FUEL_ICON := preload("res://shared/icons/fuel.svg")
const WARNING_ICON := preload("res://shared/icons/triangle_alert.svg")
const WAVE_SECONDS := 1.2
# How far the frame reaches past the gauge on each side. The gauge's own bottom margin
# already leaves room under the bar, so the bottom tucks in by a pixel.
const FRAME_SIDE := 6.0
const FRAME_TOP := 5.0
const FRAME_BOTTOM := -1.0
const FRAME_RADIUS := 6
# The frame's fill and border opacity at rest, and at the flash as a ring leaves.
const FRAME_FILL := 0.08
const FRAME_FILL_FLASH := 0.24
const FRAME_BORDER := 0.45
const FRAME_BORDER_FLASH := 0.9
# A ring spreads this far out of the frame, in this long, starting at this opacity.
const WAVE_REACH := 14.0
const WAVE_LIFE := 0.9
const WAVE_ALPHA := 0.85
const WAVE_WIDTH := 2
# How much the low bar lightens at the flash.
const BAR_LIGHTEN := 0.35

## The share of a full tank the bus holds, from 0 to 1.
var fraction := 1.0:
	set(value):
		fraction = value
		_show()

# The bar's fill, a copy of the scene's, so its colour can change.
var _fill: StyleBoxFlat
var _frame := StyleBoxFlat.new()
var _wave := StyleBoxFlat.new()
var _low := false
# Seconds since the fuel turned low, which times the rings.
var _time := 0.0


func _ready() -> void:
	var bar := %FuelBar as ProgressBar
	_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fill)
	_frame.set_border_width_all(1)
	_frame.set_corner_radius_all(FRAME_RADIUS)
	_wave.draw_center = false
	_wave.set_border_width_all(WAVE_WIDTH)
	_show()


# Low, the frame flashes and rings spread, so they change every frame.
func _process(delta: float) -> void:
	if not _low:
		return
	_time += delta
	_fill.bg_color = BusStatusPanel.FUEL_LOW_COLOR.lightened(BAR_LIGHTEN * _flash())
	queue_redraw()


func _draw() -> void:
	if not _low:
		return
	var color := BusStatusPanel.FUEL_LOW_COLOR
	var flash := _flash()
	var frame := Rect2(Vector2.ZERO, size).grow_individual(
		FRAME_SIDE, FRAME_TOP, FRAME_SIDE, FRAME_BOTTOM
	)
	_frame.bg_color = Color(color, lerpf(FRAME_FILL, FRAME_FILL_FLASH, flash))
	_frame.border_color = Color(color, lerpf(FRAME_BORDER, FRAME_BORDER_FLASH, flash))
	draw_style_box(_frame, frame)
	var age := _wave_age()
	if age >= 1.0:
		return
	var spread := ease(age, 0.4) * WAVE_REACH
	_wave.border_color = Color(color, WAVE_ALPHA * (1.0 - age) * (1.0 - age))
	_wave.set_corner_radius_all(FRAME_RADIUS + roundi(spread))
	draw_style_box(_wave, frame.grow(spread))


func _show() -> void:
	if not is_node_ready():
		return
	(%FuelBar as ProgressBar).value = fraction
	var amount := %FuelAmount as Label
	var text := "%d%%" % ceili(fraction * 100.0)
	if amount.text != text:
		amount.text = text
	var low := fraction <= BusStatusPanel.FUEL_LOW
	if low == _low:
		return
	_low = low
	_time = 0.0
	var icon := %FuelIcon as TextureRect
	icon.texture = WARNING_ICON if low else FUEL_ICON
	icon.self_modulate = BusStatusPanel.FUEL_LOW_COLOR if low else BusStatusPanel.FUEL_COLOR
	_fill.bg_color = BusStatusPanel.FUEL_LOW_COLOR if low else BusStatusPanel.FUEL_COLOR
	if low:
		amount.add_theme_color_override(&"font_color", BusStatusPanel.FUEL_LOW_COLOR)
	else:
		amount.remove_theme_color_override(&"font_color")
	queue_redraw()


# How far the newest ring has spread, from 0 as it leaves the frame to 1 once it has gone.
# Reduce motion sends none.
func _wave_age() -> float:
	if Settings.reduce_motion:
		return 1.0
	return fmod(_time, WAVE_SECONDS) / WAVE_LIFE


# The flash as a ring leaves, from 1 fading to 0 as it spreads.
func _flash() -> float:
	var age := _wave_age()
	return 0.0 if age >= 1.0 else (1.0 - age) * (1.0 - age)
