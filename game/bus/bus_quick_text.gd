class_name BusQuickText
extends Control
## A stamp of a few words with an icon that lands just above the bus when something about
## the player's driving is worth a nod, then goes after 1.5 s. Any system given it calls
## [method show_text]. It keeps its size on screen at any zoom, follows the bus while it
## shows, and hides while a planet's or the bus's panel is open, dropping any text then.
## One shows at a time: a new text takes the place of the one showing.

## What the text says about the driving, which picks its colour.
enum Kind { REMARK = 0, GAIN = 1, LOSS = 2 }

const COLORS: Dictionary[Kind, Color] = {
	## The bus's yellow: worth a nod, neither pays nor costs.
	Kind.REMARK: Color(0.96, 0.78, 0.29),
	## The gain's green: something that paid off.
	Kind.GAIN: Color(0.549, 0.851, 0.4),
	## The loss's red: something that cost.
	Kind.LOSS: Color(0.949, 0.302, 0.4),
}
const OUTLINE_COLOR := Color(0.078, 0.071, 0.188)
const SHADOW_COLOR := Color(0.043, 0.035, 0.125)
const SHADOW_OFFSET := Vector2(1.0, 2.0)
const OUTLINE_PIXELS := 2.0
const FONT_SIZE := 14
const ICON_SIZE := 15.0
const GAP := 3.0
## How tall Baloo 2's capitals are, as a share of the font size, so the icon centres on
## them.
const CAP_HEIGHT := 0.68
## Counter-clockwise, so the text climbs to the right.
const TILT_DEGREES := -5.0
## The gap between the stamp's lowest point and the top of the bus on screen, in pixels.
const BUS_GAP := 6.0
## After the camera and the bus have moved each frame, as the map's other labels.
const PROCESS_PRIORITY := 302
const FONT := preload("res://ui/fonts/baloo_2.ttf")
const WEIGHT_TAG := 2003265652
const DEBUG_GROUP := "Quick text"
const DEBUG_TEXTS: Dictionary[Kind, String] = {
	Kind.REMARK: "Quick stop!",
	Kind.GAIN: "Straight to the Moon!",
	Kind.LOSS: "Rough stop!",
}
const DEBUG_ICONS: Dictionary[Kind, Texture2D] = {
	Kind.REMARK: preload("res://game/bus/icons/timer.svg"),
	Kind.GAIN: preload("res://shared/icons/circle_check.svg"),
	Kind.LOSS: preload("res://shared/icons/fuel.svg"),
}

## The camera the bus is seen through.
@export var camera: Camera3D
@export var bus: FrameshiftBus
## The side panels: while one shows, so do no texts.
@export var panels: Array[SidePanel] = []

## How big the stamp draws, about its centre. The motion animates it.
var stamp_scale := 1.0:
	set(value):
		stamp_scale = value
		queue_redraw()

var _font := FontVariation.new()
var _text := ""
var _icon: Texture2D
var _color := Color.WHITE
var _text_width := 0.0
var _play: Tween


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	_font.base_font = FONT
	_font.variation_opentype = {WEIGHT_TAG: 800}
	hide()
	set_process(false)
	DebugPanel.add_button("Remark", _debug_show.bind(Kind.REMARK), self, DEBUG_GROUP)
	DebugPanel.add_button("Gain", _debug_show.bind(Kind.GAIN), self, DEBUG_GROUP)
	DebugPanel.add_button("Loss", _debug_show.bind(Kind.LOSS), self, DEBUG_GROUP)


func _process(_delta: float) -> void:
	if _is_panel_open():
		_stop()
		return
	var model := bus.get_model()
	var at := model.global_position
	visible = not camera.is_position_behind(at)
	var middle := camera.unproject_position(at)
	var top := camera.unproject_position(at + camera.global_basis.y * FrameshiftBus.RADIUS)
	# The tilted stamp's lowest corner, its outline and shadow included, sits BUS_GAP
	# above the bus.
	var half := _get_half_size()
	var tilt := absf(deg_to_rad(TILT_DEGREES))
	var drop := half.x * sin(tilt) + half.y * cos(tilt)
	position = Vector2(middle.x, top.y - BUS_GAP - drop)


## Shows [param text] with [param icon], a white Lucide icon, in [param kind]'s colour over
## the bus, in place of any text showing. Dropped while a panel is open.
func show_text(text: String, icon: Texture2D, kind := Kind.REMARK) -> void:
	if not camera or not bus or _is_panel_open():
		return
	_text = text
	_icon = icon
	_color = COLORS[kind]
	_text_width = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	if _play:
		_play.kill()
	show()
	set_process(true)
	_process(0.0)
	_play = create_tween()
	if Settings.reduce_motion:
		stamp_scale = 1.0
		modulate.a = 0.0
		_play.tween_property(self, ^"modulate:a", 1.0, 0.15)
		_play.tween_interval(1.15)
		_play.tween_property(self, ^"modulate:a", 0.0, 0.2)
	else:
		stamp_scale = 1.6
		modulate.a = 0.0
		# Slam: it speeds up as it lands, fading in over the first 0.08 s.
		_play.tween_property(self, ^"stamp_scale", 0.92, 0.14).set_ease(Tween.EASE_IN)
		_play.parallel().tween_property(self, ^"modulate:a", 1.0, 0.08)
		# Spring back to full size, then hold.
		_play.tween_property(self, ^"stamp_scale", 1.0, 0.11).set_ease(Tween.EASE_OUT)
		_play.tween_interval(1.05)
		# Go: shrink while fading out.
		_play.tween_property(self, ^"stamp_scale", 0.8, 0.2).set_ease(Tween.EASE_IN)
		_play.parallel().tween_property(self, ^"modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	_play.tween_callback(_stop)
	queue_redraw()


func _draw() -> void:
	if not _icon:
		return
	draw_set_transform(Vector2.ZERO, deg_to_rad(TILT_DEGREES), Vector2.ONE * stamp_scale)
	_draw_stamp(SHADOW_OFFSET, SHADOW_COLOR, SHADOW_COLOR)
	_draw_stamp(Vector2.ZERO, _color, OUTLINE_COLOR)


# The icon and the text centred on the origin, moved by offset, in fill with an outline.
func _draw_stamp(offset: Vector2, fill: Color, outline: Color) -> void:
	var left := offset.x - (ICON_SIZE + GAP + _text_width) * 0.5
	var icon_rect := Rect2(Vector2(left, offset.y - ICON_SIZE * 0.5), Vector2.ONE * ICON_SIZE)
	var baseline := Vector2(left + ICON_SIZE + GAP, offset.y + FONT_SIZE * CAP_HEIGHT * 0.5)
	# A texture has no outline, so it is drawn in the outline's colour all round.
	for i: int in 16:
		var ring := Vector2.from_angle(TAU * i / 16.0) * OUTLINE_PIXELS
		draw_texture_rect(_icon, Rect2(icon_rect.position + ring, icon_rect.size), false, outline)
	draw_string_outline(
		_font,
		baseline,
		_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		int(OUTLINE_PIXELS * 2.0),
		outline
	)
	# Lucide's lines are 1.4 px at this size; drawn a little off-centre all round they read
	# as 2 px, beside the heavy text.
	for i: int in 8:
		var thicken := Vector2.from_angle(TAU * i / 8.0) * 0.3
		draw_texture_rect(_icon, Rect2(icon_rect.position + thicken, icon_rect.size), false, fill)
	draw_string(_font, baseline, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, fill)


# Half the stamp's untilted size at full scale, outline and shadow included.
func _get_half_size() -> Vector2:
	var width := ICON_SIZE + GAP + _text_width + OUTLINE_PIXELS * 2.0
	var height := ICON_SIZE + OUTLINE_PIXELS * 2.0
	return (Vector2(width, height) + SHADOW_OFFSET) * 0.5


func _is_panel_open() -> bool:
	return panels.any(func(panel: SidePanel) -> bool: return panel.visible)


func _stop() -> void:
	if _play:
		_play.kill()
	hide()
	set_process(false)


func _debug_show(kind: Kind) -> void:
	show_text(DEBUG_TEXTS[kind], DEBUG_ICONS[kind], kind)
