class_name HudLayout
extends CanvasLayer
## The solar system's HUD layer. While a side panel is open, it hides the bus bars and the
## notices above them, which sit under the panel, fades the goal panel out, which the panel
## would slice, and keeps the resource bar centred in the gap
## between the On board panel and the side panel, so the bar glides aside as the side
## panel slides in and back as it slides out. The notices sit on top of the bus bars, so
## they rise and fall with the route bar as it opens and closes.
## For the tutorial's call, [method hide_for_call] covers the screen in black and fades it
## in slowly once the scene change is over, with only the bus bars and the notices
## showing, and the screen takes no clicks but on the notices and guide cards until
## [method uncover]. [method cover] blocks clicks the same way without the black, as for the
## tutorial's last call. [method reveal] brings in the parts the tutorial asks for when it
## wants them. [method hide_all] takes every panel and the bus bars out at the tutorial's
## end, and [method reveal_all] brings everything back.

## The screen has faded in from black after [method hide_for_call].
signal faded_in

## The parts [method hide_for_call] hides.
enum Part { RESOURCE_BAR, ON_BOARD, STATION }

## Seconds the screen takes to fade in from black.
const FADE_IN_SECONDS := 2.5
## Seconds each hidden part takes to come in on [method reveal], from one starting to the
## next, and how far it drops into place, in pixels.
const REVEAL_SECONDS := 0.5
const REVEAL_STEP := 0.08
const REVEAL_DROP := 12.0
## Seconds each part takes to go on [method hide_all], one after another.
const LEAVE_SECONDS := 0.35
## Seconds the goal panel takes to fade out and back, also under Reduce motion.
const GOAL_FADE_SECONDS := 0.2

# The resource bar's margins, left and right, as last set.
var _margins := Vector2i.ZERO
# Whether the goal panel is faded out for an open side panel, and the tween that fades it.
var _goals_hidden := false
var _goal_fade: Tween
var _fade: Tween
# Whether the bus bars and the notices are out, after hide_all().
var _bars_out := false


func _process(_delta: float) -> void:
	var side := (%BusPanel if (%BusPanel as Control).visible else %PlanetPanel) as Control
	(%Notices as Control).visible = not side.visible
	(%BusStatusPanel as Control).visible = not side.visible
	# By the bars' height this frame, not the panel's offsets, which it sets after this
	# runs: the route bar has already eased its height (it runs first).
	var notices := %Notices as Control
	notices.offset_bottom = -(%BusStatusPanel as Control).get_combined_minimum_size().y
	notices.offset_top = notices.offset_bottom
	if side.visible != _goals_hidden:
		_goals_hidden = side.visible
		_fade_goals()
	var covered := get_viewport().get_visible_rect().end.x - side.global_position.x
	var margins := Vector2i.ZERO
	if side.visible and covered > 0.0:
		var left := (%PassengerPanel as Control).get_global_rect().end.x
		margins = Vector2i(roundi(left), roundi(covered))
	if margins != _margins:
		_margins = margins
		var top := %TopCentre as Control
		top.add_theme_constant_override(&"margin_left", margins.x)
		top.add_theme_constant_override(&"margin_right", margins.y)


## Hides all but the bus bars and the notices, under black that fades out once the scene
## change is over ([signal faded_in]). Until [method uncover], the screen takes no clicks
## but on the notices.
func hide_for_call() -> void:
	for part: Part in Part.values():
		_control(part).visible = false
	var curtain := %Curtain as Control
	curtain.modulate.a = 1.0
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.show()
	while SceneFlow.is_busy():
		await get_tree().process_frame
	# Revealed meanwhile, as when the tutorial is skipped.
	if not curtain.visible:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(curtain, "modulate:a", 0.0, FADE_IN_SECONDS)
	await _fade.finished
	faded_in.emit()


## Makes the screen take no clicks but on the notices and guide cards, with nothing hidden,
## until [method uncover].
func cover() -> void:
	if _fade:
		_fade.kill()
	var curtain := %Curtain as Control
	curtain.modulate.a = 0.0
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.show()


## Lets the screen take clicks again after [method hide_for_call] or [method cover].
func uncover() -> void:
	if _fade:
		_fade.kill()
	(%Curtain as Control).hide()


## Brings in those of [param parts] that are hidden, one after another, each fading in as
## it drops into place; under Reduce motion they only fade. It returns once they are in.
func reveal(parts: Array[Part]) -> void:
	var hidden: Array[Control] = []
	for part: Part in parts:
		var control := _control(part)
		if not control.visible:
			hidden.append(control)
	if hidden.is_empty():
		return
	for control: Control in hidden:
		control.modulate.a = 0.0
		control.show()
	# The parts lay out once shown, so they drop to where they settle.
	await get_tree().process_frame
	# Its own tween each time, so a later call leaves those still coming in alone.
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var delay := 0.0
	for control: Control in hidden:
		tween.tween_property(control, "modulate:a", 1.0, REVEAL_SECONDS).set_delay(delay)
		if not Settings.reduce_motion:
			var rest := control.position.y
			control.position.y = rest - REVEAL_DROP
			tween.tween_property(control, "position:y", rest, REVEAL_SECONDS).set_delay(delay)
		delay += REVEAL_STEP
	await tween.finished


## Takes out every panel showing, the bus bars and the notices, one after another, each
## fading out as it moves toward its edge; under Reduce motion they only fade. It returns
## once they are gone. The bars and notices stay out, see-through, until
## [method reveal_all].
func hide_all() -> void:
	var tops: Array[Control] = []
	for part: Part in Part.values():
		if _control(part).visible:
			tops.append(_control(part))
	var leaving: Array[Control] = tops.duplicate()
	if not _bars_out:
		leaving.append_array([%BusStatusPanel, %Notices])
	_bars_out = true
	if leaving.is_empty():
		return
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	var rests: Dictionary[Control, float] = {}
	var delay := 0.0
	for control: Control in leaving:
		tween.tween_property(control, "modulate:a", 0.0, LEAVE_SECONDS).set_delay(delay)
		# The notices' place is the layout's to keep, every frame.
		if not Settings.reduce_motion and control != %Notices:
			rests[control] = control.position.y
			var away := -REVEAL_DROP if control in tops else REVEAL_DROP
			var to := control.position.y + away
			tween.tween_property(control, "position:y", to, LEAVE_SECONDS).set_delay(delay)
		delay += REVEAL_STEP
	await tween.finished
	for control: Control in rests:
		control.position.y = rests[control]
	for control: Control in tops:
		control.hide()


## Brings in everything hidden, the panels as [method reveal] does and the bus bars and the
## notices after [method hide_all], and lets the screen take clicks.
func reveal_all() -> void:
	uncover()
	reveal([Part.RESOURCE_BAR, Part.ON_BOARD, Part.STATION])
	if not _bars_out:
		return
	_bars_out = false
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for control: Control in [%BusStatusPanel, %Notices]:
		tween.tween_property(control, "modulate:a", 1.0, REVEAL_SECONDS)
	if not Settings.reduce_motion:
		var bars := %BusStatusPanel as Control
		var rest := bars.position.y
		bars.position.y = rest + REVEAL_DROP
		tween.tween_property(bars, "position:y", rest, REVEAL_SECONDS)


func _control(part: Part) -> Control:
	match part:
		Part.RESOURCE_BAR:
			return %TopCentre
		Part.ON_BOARD:
			return %PassengerPanel
	return %TopRight


func _fade_goals() -> void:
	var goals := %GoalPanel as Control
	if _goal_fade:
		_goal_fade.kill()
	_goal_fade = create_tween()
	_goal_fade.tween_property(
		goals, ^"modulate:a", 0.0 if _goals_hidden else 1.0, GOAL_FADE_SECONDS
	)
