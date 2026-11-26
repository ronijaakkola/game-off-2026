class_name JumpCard
extends Button
## The goal panel's way on to the next star system after a promotion the player stayed for:
## a wide band of the next level's picture, or the system's sky colours when the level has
## none, with "Jump to level <n>" over the level's name, and an arrow at the right. The pointer or
## the focus on it zooms the picture in a little, as the campaign screen's picked card does,
## and brightens its border; nothing else on it moves. Once pressed, [method hold] dims it
## until the jump. Under Reduce motion the picture holds still.

const LEVEL := "Jump to level %d"
## How far the picture zooms in while the pointer is on the card, and the seconds it takes.
const HOVER_ZOOM := 1.05
const HOVER_SECONDS := 0.3
## How see-through the border is at rest, against while the pointer is on the card, and the
## seconds it takes to brighten.
const BORDER_ALPHA := 0.4
const BORDER_SECONDS := 0.15
## The levels' pictures are 16:9.
const PICTURE_ASPECT := 16.0 / 9.0
## How see-through the card is once pressed, until the jump.
const HELD_ALPHA := 0.55

var _material: ShaderMaterial
# Where the band centres in the level's picture, in shares of its height from the top.
var _band_middle := 0.45
var _hovered := false
var _hover: Tween


func _ready() -> void:
	_material = (%Picture as CanvasItem).material as ShaderMaterial
	_material.set_shader_parameter(&"zoom", 1.0)
	(%Picture as Control).resized.connect(_on_picture_resized)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_on_picture_resized()


## Shows the jump to [param system]: its level's number, name and picture, or the system's
## own name when it is no level's. It can be pressed again.
func show_system(system: StarSystem) -> void:
	var level := Campaign.find(String(system.name))
	(%Title as Label).text = level.title if level else system.display_name
	(%Level as Label).visible = level != null
	if level:
		(%Level as Label).text = LEVEL % Campaign.number(level)
		_band_middle = level.jump_band_middle
	var has_picture := level != null and not level.picture.is_empty()
	_material.set_shader_parameter(&"has_picture", has_picture)
	_material.set_shader_parameter(&"picture", load(level.picture) if has_picture else null)
	_material.set_shader_parameter(&"left_color", system.background_color)
	_material.set_shader_parameter(&"right_color", system.fog_accent_color.lightened(0.15))
	_on_picture_resized()
	disabled = false
	modulate.a = 1.0


## Lets go of the picture, so it isn't kept in memory once the jump is taken.
func clear() -> void:
	_material.set_shader_parameter(&"picture", null)


## Pressed: it takes no more presses and dims until the jump.
func hold() -> void:
	disabled = true
	modulate.a = HELD_ALPHA
	_set_hovered(false)


func _set_hovered(on: bool) -> void:
	on = on and not disabled
	if on == _hovered:
		return
	_hovered = on
	if _hover:
		_hover.kill()
	_hover = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	var border := 1.0 if on else BORDER_ALPHA
	_hover.tween_property(%Border, ^"self_modulate:a", border, BORDER_SECONDS)
	if Settings.reduce_motion:
		return
	var zoom := HOVER_ZOOM if on else 1.0
	_hover.tween_property(_material, ^"shader_parameter/zoom", zoom, HOVER_SECONDS).set_trans(
		Tween.TRANS_QUART
	)


# The band is the picture's full width, as tall as the card's shape allows, centred where
# the level says, as near as the picture's top and bottom let it.
func _on_picture_resized() -> void:
	var size_now := (%Picture as Control).size
	_material.set_shader_parameter(&"size", size_now)
	if size_now.y > 0.0:
		var height := clampf(PICTURE_ASPECT / (size_now.x / size_now.y), 0.0, 1.0)
		var top := clampf(_band_middle - height * 0.5, 0.0, 1.0 - height)
		_material.set_shader_parameter(&"region", Vector4(0.0, top, 1.0, height))
