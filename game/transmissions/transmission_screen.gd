class_name TransmissionScreen
extends PanelContainer
## The screen a transmission's caller talks from: their live portrait, framed in their
## skin colour over a backdrop in their race's deep shade, behind an old tube's scanlines and
## static. It renders the portrait in its own viewport, which runs while the game is paused
## and only while a caller shows, big enough to stay sharp at the screen's size. The
## shared [PortraitStudio] pauses with the game, and its tiles are card-sized.
## [method turn_on] starts the tube with a burst of static; while [member talking], the
## caller's head bobs as if with each word and their eyes stay on the player.

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
## The lights coming on over a shadowed caller: seconds lit, then dark, in turn, as a tube
## that flickers before it catches. It ends lit.
const FLICKER: Array[float] = [0.05, 0.22, 0.07, 0.12, 0.04, 0.3, 0.12, 0.07]
## Seconds from the lights starting to come on until they are on.
const LIGHT_SECONDS := 0.99

## Whether the caller is talking.
var talking := false

var _portrait: AlienPortrait
var _talk := 0.0
var _talk_time := 0.0
# The one tween that turns the tube on or off.
var _power: Tween
# The caller in the light, while the lights come on over their outline, and the tween that
# flickers between the two.
var _lit: AlienPortrait
var _lights: Tween


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
	_portrait = _add_portrait(transmission, transmission.shadowed)
	_show_room(transmission, transmission.shadowed)
	_show_badges(transmission.type)
	(%Viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Dresses [param portrait], already in the tree, as [param transmission]'s caller: their
## mood on their face, or with [param dark], only their outline, with no eyes or colour.
## The small [CallerPhoto] dresses its portrait here too, so the two never differ.
static func dress(portrait: AlienPortrait, transmission: Transmission, dark: bool) -> void:
	if dark:
		portrait.paint_over(SHADOW_SKIN)
	elif transmission.stern:
		portrait.anger = 1.0
		portrait.shows_fury = false
	else:
		portrait.anger = PassengerPhoto.MOOD_ANGER.get(transmission.mood, 0.0)
		portrait.content = transmission.mood == Passenger.Mood.HAPPY
	for eye: MeshInstance3D in portrait.eyes:
		eye.visible = not dark


## The backdrop behind [param transmission]'s caller: the dark room's with [param dark].
static func get_backdrop_color(transmission: Transmission, dark: bool) -> Color:
	return SHADOW_BACKDROP if dark else transmission.get_backdrop_color()


## Whether the backdrop behind [param transmission]'s caller is space: never with
## [param dark].
static func is_in_space(transmission: Transmission, dark: bool) -> bool:
	return transmission.in_space and not dark


## The frame round [param transmission]'s caller: their skin colour, or the dark room's
## with [param dark].
static func get_frame_color(transmission: Transmission, dark: bool) -> Color:
	return SHADOW_FRAME if dark else transmission.look.skin_color


## Turns the lights on over [param transmission]'s caller, who sat in the dark: they
## flicker a few times ([constant FLICKER]) and stay on, showing the caller's face, colour
## and room. Under Reduce motion they come on at once.
func light_up(transmission: Transmission) -> void:
	if not _portrait or _lit:
		return
	_lit = _add_portrait(transmission, false)
	if _lights:
		_lights.kill()
	_lights = create_tween()
	if not Settings.reduce_motion:
		for i: int in FLICKER.size():
			_lights.tween_callback(_set_lit.bind(transmission, i % 2 == 0))
			_lights.tween_interval(FLICKER[i])
	_lights.tween_callback(_finish_lighting.bind(transmission))


## Takes the caller off the screen and stops rendering.
func clear() -> void:
	if _lights:
		_lights.kill()
	if _lit:
		_lit.queue_free()
		_lit = null
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


# A portrait of [param transmission]'s caller on the screen, dressed for the dark room with
# [param dark].
func _add_portrait(transmission: Transmission, dark: bool) -> AlienPortrait:
	var portrait := PortraitStudio.new_portrait(transmission.look, transmission.type)
	%Talk.add_child(portrait)
	PortraitStudio.frame(portrait)
	dress(portrait, transmission, dark)
	return portrait


# The backdrop behind [param transmission]'s caller and the frame round them: the dark
# room's with [param dark].
func _show_room(transmission: Transmission, dark: bool) -> void:
	var backdrop := (%Backdrop as ColorRect).material as ShaderMaterial
	backdrop.set_shader_parameter(&"backdrop_color", get_backdrop_color(transmission, dark))
	backdrop.set_shader_parameter(&"space", is_in_space(transmission, dark))
	var border := (%Border as Panel).get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	border.border_color = get_frame_color(transmission, dark)
	(%Border as Panel).add_theme_stylebox_override(&"panel", border)


# Shows the caller in the light or as their outline, while the lights flicker.
func _set_lit(transmission: Transmission, lit: bool) -> void:
	_lit.visible = lit
	_portrait.visible = not lit
	_show_room(transmission, not lit)


# The lights are on: the outline goes, and the caller in the light is the one on screen.
func _finish_lighting(transmission: Transmission) -> void:
	_set_lit(transmission, true)
	_portrait.queue_free()
	_portrait = _lit
	_lit = null


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
