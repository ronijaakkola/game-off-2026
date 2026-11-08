class_name FuelButton
extends Button
## A button to hold down to refuel that is also the tank's gauge: a faint fill behind the
## label, as wide as the share of a full tank the bus holds, which grows as fuel flows in.
## It reads "Hold to fuel" with what filling the tank costs, as "Hold to fuel (51 cr)";
## held, the label morphs into the fuel's percentage, which counts up as the tank fills,
## and back when let go. Off, it reads why instead. Low fuel fills in
## the bus status's low colour, at the same share of a tank. The parent pumps while
## [method is_held] and sets what shows with [method show_fuel].
## The button's own text stays empty: a child label draws it, over the fill. Its corners
## are as round as the cards' rows, and the fill's with them.

const IDLE_TEXT := "Hold to fuel (%d cr)"
## The corners' radius, for the button and the fill alike.
const CORNER_RADIUS := 6
# The button's styleboxes, each rounded to CORNER_RADIUS.
const STYLES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"
]
## How opaque the fill is, so the label stays readable over a full tank.
const FILL_ALPHA := 0.3

var _held := false
var _fraction := 1.0
var _cost := 0
# The fill's style: a flat box with the button's corners, so a full tank fills it exactly.
var _fill_style := StyleBoxFlat.new()


func _ready() -> void:
	# Keeps the height the button's own text gave it, which the label inside doesn't.
	custom_minimum_size.y = maxf(custom_minimum_size.y, get_minimum_size().y)
	text = ""
	for style_name: StringName in STYLES:
		var style := get_theme_stylebox(style_name).duplicate() as StyleBox
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).set_corner_radius_all(CORNER_RADIUS)
		add_theme_stylebox_override(style_name, style)
	_fill_style.set_corner_radius_all(CORNER_RADIUS)
	(%Fill as Panel).add_theme_stylebox_override(&"panel", _fill_style)
	(%Label as Label).text = IDLE_TEXT % _cost
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_place_fill)
	show_fuel(_fraction, _cost, true, "")


func _notification(what: int) -> void:
	# Hidden while held, as when the dock panel goes, it may never see the release.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_held = false


## Whether the button is held down.
func is_held() -> bool:
	return _held


## Shows [param fraction] of a full tank in the fill and, while held, as the label, and
## [param cost], the credits to fill the tank, while not. With [param can_fuel] false the
## button is off, lets go and reads [param reason].
func show_fuel(fraction: float, cost: int, can_fuel: bool, reason: String) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	_cost = cost
	disabled = not can_fuel
	if not can_fuel:
		_held = false
	var low := _fraction <= BusStatusPanel.FUEL_LOW
	var color := BusStatusPanel.FUEL_LOW_COLOR if low else BusStatusPanel.FUEL_COLOR
	_fill_style.bg_color = Color(color, FILL_ALPHA)
	_place_fill()
	var label := %Label as MorphLabel
	label.modulate.a = 0.5 if disabled else 1.0
	var wanted := reason
	if can_fuel:
		wanted = "%d%%" % ceili(_fraction * 100.0) if _held else IDLE_TEXT % _cost
	if label.is_morphing() or wanted == label.text:
		return
	# Into or out of the percentage, or to a reason, it morphs; the count itself just ticks.
	if label.text.ends_with("%") and wanted.ends_with("%"):
		label.text = wanted
	else:
		label.morph_to(wanted)


func _place_fill() -> void:
	var fill := %Fill as Control
	fill.position = Vector2.ZERO
	fill.size = Vector2(size.x * _fraction, size.y)


func _on_button_down() -> void:
	_held = true


func _on_button_up() -> void:
	_held = false
