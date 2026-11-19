class_name WaitingCard
extends CanvasGroup
## Who waits at a planet, as a small dark card under its name: each one's photo over their
## destination's icon, with no text. It opens as it grows out of the name, fading in from a
## little smaller, and closes faster, only fading and shrinking back a little. Turned round
## mid-way, it runs from where it is. Under Reduce motion it only fades.
## It is a group, drawn as one and faded as one: the photos are premultiplied and the
## planet icons draw their own colour, so faded one by one they would stay bright over a
## card fading under them.
## Its origin is the middle of the card's top edge, which it grows from.

## The photo's and the destination icon's sizes, and the gaps round them, in pixels.
const PHOTO_SIZE := 24.0
const ICON_SIZE := 14.0
const PHOTO_GAP := 4
const COLUMN_GAP := 8
## The tooltips' dark navy, a little see-through, with the surface's faint rim.
const COLOR := Color(0.043, 0.035, 0.125, 0.95)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const RADIUS := 8
const PADDING := Vector4(9.0, 7.0, 9.0, 6.0)
## Seconds to open and to close, and the scale it grows from and shrinks to.
const OPEN_SECONDS := 0.18
const CLOSE_SECONDS := 0.12
const OPEN_FROM_SCALE := 0.95
const CLOSE_TO_SCALE := 0.97
const PHOTO := preload("res://game/passengers/passenger_photo.tscn")

var _panel := PanelContainer.new()
var _columns := HBoxContainer.new()
var _open := false
var _motion: Tween


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_right = PADDING.z
	style.content_margin_bottom = PADDING.w
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	_panel.add_child(_columns)
	add_child(_panel)
	visible = false
	self_modulate.a = 0.0


## Shows [param line], longest waiting first, with photos from [param studio].
func show_line(line: Array[Passenger], studio: PortraitStudio) -> void:
	_clear()
	for passenger: Passenger in line:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override(&"separation", PHOTO_GAP)
		var photo := PHOTO.instantiate() as PassengerPhoto
		photo.custom_minimum_size = Vector2.ONE * PHOTO_SIZE
		photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		photo.studio = studio
		photo.passenger = passenger
		column.add_child(photo)
		var icon := PlanetIcon.new()
		icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.planet = passenger.destination
		column.add_child(icon)
		_columns.add_child(column)
	_panel.reset_size()
	_panel.position = Vector2(-roundf(_panel.size.x * 0.5), 0.0)


## Opens it, from where it is if it was closing.
func open() -> void:
	if _open:
		return
	if not visible:
		scale = Vector2.ONE * OPEN_FROM_SCALE
	_open = true
	show()
	_animate(1.0, 1.0, OPEN_SECONDS)


## Closes it, from where it is if it was opening, and lets its photos go once it is gone.
func close() -> void:
	if not _open:
		return
	_open = false
	_animate(0.0, CLOSE_TO_SCALE, CLOSE_SECONDS)
	_motion.chain().tween_callback(_on_closed)


## Whether it is open or opening.
func is_open() -> bool:
	return _open


# The movement eases out hard; the fade more gently, or it would be over before the
# movement shows.
func _animate(alpha: float, to_scale: float, seconds: float) -> void:
	if _motion:
		_motion.kill()
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, ^"self_modulate:a", alpha, seconds).set_trans(Tween.TRANS_QUAD)
	if Settings.reduce_motion:
		scale = Vector2.ONE
	else:
		_motion.tween_property(self, ^"scale", Vector2.ONE * to_scale, seconds)


func _on_closed() -> void:
	hide()
	_clear()


func _clear() -> void:
	for column: Node in _columns.get_children():
		_columns.remove_child(column)
		column.queue_free()
