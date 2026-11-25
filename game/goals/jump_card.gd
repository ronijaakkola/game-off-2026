class_name JumpCard
extends Button
## The goal panel's way on to the next star system after a promotion the player stayed for:
## a wide band of the next level's picture, or the system's sky colours when the level has
## none, with "Jump to <system>" over the level's number and name, and an arrow at the right
## that nudges on every [constant NUDGE_EVERY] seconds. The pointer or the focus on it
## brightens the picture, zooms it in a little and moves the arrow on. Once pressed,
## [method hold] dims it until the jump. Under Reduce motion only the brightness changes.

const TITLE := "Jump to %s"
const LEVEL := "Level %d · %s"
## How far the picture zooms in while the pointer is on the card, and the seconds it takes.
const HOVER_ZOOM := 1.06
const HOVER_SECONDS := 0.3
## Pixels the arrow moves on while the pointer is on the card.
const HOVER_SHIFT := 4.0
## Seconds between the arrow's nudges, and how far and how fast each goes out and back.
const NUDGE_EVERY := 2.4
const NUDGE_SHIFT := 5.0
const NUDGE_SECONDS := 0.22
## The levels' pictures are 16:9.
const PICTURE_ASPECT := 16.0 / 9.0
## How far above the middle of the level's card crop the band centres, in shares of the
## picture's height: the pictures' subject sits a little above their middle.
const BAND_LIFT := 0.09
## How see-through the card is once pressed, until the jump.
const HELD_ALPHA := 0.55

var _material: ShaderMaterial
# The level's card crop, whose middle the band centres on, or empty without a picture.
var _crop := Rect2()
var _hovered := false
var _hover: Tween
var _arrow: Tween
var _nudge: Tween


func _ready() -> void:
	_material = (%Picture as CanvasItem).material as ShaderMaterial
	(%Picture as Control).resized.connect(_on_picture_resized)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_on_picture_resized()


## Shows the jump to [param system]: its name, and its level's number, name and picture.
## Pressable again, it starts nudging.
func show_system(system: StarSystem) -> void:
	var level := Campaign.find(String(system.name))
	(%Title as Label).text = TITLE % system.display_name
	(%Level as Label).visible = level != null
	if level:
		(%Level as Label).text = LEVEL % [Campaign.number(level), level.title]
	var has_picture := level != null and not level.picture.is_empty()
	_crop = level.card_crop if has_picture else Rect2()
	_material.set_shader_parameter(&"has_picture", has_picture)
	_material.set_shader_parameter(&"picture", load(level.picture) if has_picture else null)
	_material.set_shader_parameter(&"left_color", system.background_color)
	_material.set_shader_parameter(&"right_color", system.fog_accent_color.lightened(0.15))
	_on_picture_resized()
	disabled = false
	modulate.a = 1.0
	_start_nudging()


## Lets go of the picture, so it isn't kept in memory once the jump is taken.
func clear() -> void:
	_material.set_shader_parameter(&"picture", null)
	_stop_nudging()


## Pressed: it takes no more presses and dims until the jump.
func hold() -> void:
	disabled = true
	modulate.a = HELD_ALPHA
	_set_hovered(false)
	_stop_nudging()


func _set_hovered(on: bool) -> void:
	on = on and not disabled
	if on == _hovered:
		return
	_hovered = on
	if _hover:
		_hover.kill()
	var light := 1.0 if on else 0.0
	if Settings.reduce_motion:
		_material.set_shader_parameter(&"light", light)
		return
	_hover = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_hover.tween_property(_material, ^"shader_parameter/light", light, HOVER_SECONDS)
	var zoom := HOVER_ZOOM if on else 1.0
	_hover.tween_property(_material, ^"shader_parameter/zoom", zoom, HOVER_SECONDS)
	_new_arrow_tween().tween_property(
		%Arrow, ^"position:x", HOVER_SHIFT if on else 0.0, HOVER_SECONDS
	)


# Every so often the arrow nudges on and back, unless the pointer is on the card.
func _start_nudging() -> void:
	_stop_nudging()
	if Settings.reduce_motion:
		return
	_nudge = create_tween().set_loops()
	_nudge.tween_interval(NUDGE_EVERY)
	_nudge.tween_callback(_nudge_once)


func _nudge_once() -> void:
	if _hovered or Settings.reduce_motion:
		return
	var tween := _new_arrow_tween()
	tween.tween_property(%Arrow, ^"position:x", NUDGE_SHIFT, NUDGE_SECONDS)
	tween.tween_property(%Arrow, ^"position:x", 0.0, NUDGE_SECONDS * 1.6)


func _stop_nudging() -> void:
	if _nudge:
		_nudge.kill()
		_nudge = null
	if _arrow:
		_arrow.kill()
	(%Arrow as Control).position.x = 0.0


# The arrow's one tween, the last one killed.
func _new_arrow_tween() -> Tween:
	if _arrow:
		_arrow.kill()
	_arrow = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	return _arrow


# The band is the picture's full width, as tall as the card's shape allows, centred a little
# above the middle of the level's card crop where it fits.
func _on_picture_resized() -> void:
	var size_now := (%Picture as Control).size
	_material.set_shader_parameter(&"size", size_now)
	if _crop.has_area() and size_now.y > 0.0:
		var height := clampf(PICTURE_ASPECT / (size_now.x / size_now.y), 0.0, 1.0)
		var middle := _crop.get_center().y - BAND_LIFT
		var top := clampf(middle - height * 0.5, 0.0, 1.0 - height)
		_material.set_shader_parameter(&"region", Vector4(0.0, top, 1.0, height))
