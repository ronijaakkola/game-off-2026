class_name TransmissionScreen
extends PanelContainer
## The screen a transmission's caller talks from: their live portrait, framed in their
## race's skin colour over a backdrop in its deep shade, behind an old tube's scanlines and
## static. It renders the portrait in its own viewport, which runs while the game is paused
## and only while a caller shows, big enough to stay sharp at the screen's size. The
## shared [PortraitStudio] pauses with the game, and its tiles are card-sized.
## [method turn_on] starts the tube with a burst of static; while [member talking], the
## caller's head bobs as if with each word and their eyes stay on the player.

const PORTRAIT := preload("res://game/passengers/alien_portrait.tscn")
const BADGE := preload("res://game/passengers/photo_badge.tscn")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
## Seconds the tube takes to turn on, and to turn off.
const ON_SECONDS := 0.9
const OFF_SECONDS := 0.4
## The static over the picture once it is on, and at the start of turning on.
const STATIC_REST := 0.06
const STATIC_BURST := 0.7
## A badge's side and the gap round its icon, in whole pixels, so the icon sits dead centre.
const BADGE_SIZE := 28.0
const BADGE_PAD := 6.0
## Talking, the head bobs: how fast, how high in the model's units, and how far it nods,
## in radians. A slower wave varies each bob, so it doesn't tick like a metronome.
const TALK_SPEED := 13.0
const TALK_LIFT := 0.025
const TALK_NOD := 0.06
## How fast the bob comes and goes as talking starts and stops, per second.
const TALK_BLEND := 6.0
## A shadowed caller: their skin, the dark room behind them, whose gloom the backdrop
## lifts enough to show their outline, and their frame.
const SHADOW_SKIN := Color(0.035, 0.03, 0.06)
const SHADOW_BACKDROP := Color(0.02, 0.02, 0.07)
const SHADOW_FRAME := Color(0.2, 0.19, 0.26)

## Whether the caller is talking.
var talking := false

var _portrait: AlienPortrait
var _talk := 0.0
var _talk_time := 0.0
# The one tween that turns the tube on or off.
var _power: Tween


func _ready() -> void:
	(%Photo as TextureRect).texture = (%Viewport as SubViewport).get_texture()
	_crt().set_shader_parameter(&"power", 0.0)


func _process(delta: float) -> void:
	if not _portrait:
		return
	var motion := 0.0 if Settings.reduce_motion else 1.0
	_talk = move_toward(_talk, 1.0 if talking else 0.0, delta * TALK_BLEND)
	_talk_time += delta
	var t := _talk_time * TALK_SPEED
	var bob := absf(sin(t)) * (0.7 + 0.3 * sin(t * 0.29)) * _talk * motion
	var talk := %Talk as Node3D
	talk.position.y = bob * TALK_LIFT
	talk.rotation.x = -bob * TALK_NOD
	if talking:
		_portrait.look_toward(Vector2.ZERO)


## Puts [param transmission]'s caller on the screen, with the tube off.
func show_caller(transmission: Transmission) -> void:
	clear()
	_portrait = PORTRAIT.instantiate() as AlienPortrait
	_portrait.head_model = transmission.look.head
	_portrait.eye_style = transmission.look.eye_style
	var dark := transmission.shadowed
	_portrait.skin_color = SHADOW_SKIN if dark else transmission.look.skin_color
	if dark:
		_portrait.outfit_color = SHADOW_SKIN
	elif transmission.stern:
		_portrait.anger = 1.0
		_portrait.shows_fury = false
	else:
		_portrait.anger = PassengerPhoto.MOOD_ANGER.get(transmission.mood, 0.0)
		_portrait.content = transmission.mood == Passenger.Mood.HAPPY
	%Talk.add_child(_portrait)
	PortraitStudio.frame(_portrait)
	for eye: MeshInstance3D in _portrait.eyes:
		eye.visible = not dark
	var backdrop := (%Backdrop as ColorRect).material as ShaderMaterial
	backdrop.set_shader_parameter(
		&"backdrop_color", SHADOW_BACKDROP if dark else Race.BACKDROP_COLORS[transmission.race]
	)
	var border := (%Border as Panel).get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	border.border_color = SHADOW_FRAME if dark else Race.SKIN_COLORS[transmission.race]
	(%Border as Panel).add_theme_stylebox_override(&"panel", border)
	_show_badges(transmission.type)
	(%Viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Takes the caller off the screen and stops rendering.
func clear() -> void:
	if _portrait:
		_portrait.queue_free()
		_portrait = null
	talking = false
	_talk = 0.0
	(%Viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED


## Turns the tube on: a bright line opens into the picture under a burst of static that
## settles to a faint snow. Under Reduce motion the picture fades in with no burst.
func turn_on() -> void:
	var crt := _crt()
	var still := Settings.reduce_motion
	crt.set_shader_parameter(&"motion", 0.0 if still else 1.0)
	crt.set_shader_parameter(&"static_amount", STATIC_REST if still else STATIC_BURST)
	if _power:
		_power.kill()
	_power = create_tween()
	if still:
		crt.set_shader_parameter(&"power", 1.0)
		(%Tube as Control).modulate.a = 0.0
		_power.tween_property(%Tube, "modulate:a", 1.0, ON_SECONDS)
		return
	(%Tube as Control).modulate.a = 1.0
	_power.set_ease(Tween.EASE_OUT)
	_power.tween_method(_set_power, 0.0, 1.0, ON_SECONDS).set_trans(Tween.TRANS_QUART)
	(
		_power
		. parallel()
		. tween_method(_set_static, STATIC_BURST, STATIC_REST, ON_SECONDS * 1.6)
		. set_trans(Tween.TRANS_CUBIC)
	)


## Turns the tube off, closing the picture to a line. Under Reduce motion it fades out.
func turn_off() -> void:
	if _power:
		_power.kill()
	_power = create_tween()
	if Settings.reduce_motion:
		_power.tween_property(%Tube, "modulate:a", 0.0, OFF_SECONDS)
		return
	# Eased both ways, so both steps show: the picture closing to a line, then the line
	# closing to the middle.
	_power.tween_method(_set_power, 1.0, 0.0, OFF_SECONDS).set_ease(Tween.EASE_IN_OUT).set_trans(
		Tween.TRANS_CUBIC
	)


# The type's badges, each with the type's tooltip as on a passenger's photo; none without
# a type.
func _show_badges(type: PassengerType) -> void:
	var badges := %Badges as Control
	for badge: Node in badges.get_children():
		badges.remove_child(badge)
		badge.queue_free()
	if not type:
		return
	for texture: Texture2D in type.badges:
		var badge := BADGE.instantiate() as PhotoBadge
		badge.show_icon(texture, BADGE_SIZE, BADGE_PAD)
		if not type.description.is_empty():
			badge.mouse_filter = Control.MOUSE_FILTER_PASS
			var tooltip := TOOLTIP.instantiate() as Tooltip
			tooltip.target = badge
			tooltip.title = type.display_name
			tooltip.sentence = type.description
			badge.add_child(tooltip)
		badges.add_child(badge)
	badges.size = badges.get_combined_minimum_size()


func _set_power(value: float) -> void:
	_crt().set_shader_parameter(&"power", value)


func _set_static(value: float) -> void:
	_crt().set_shader_parameter(&"static_amount", value)


func _crt() -> ShaderMaterial:
	return (%Crt as ColorRect).material as ShaderMaterial
