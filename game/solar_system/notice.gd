class_name Notice
extends Control
## One notice in the [NoticeStack]: an icon and a line of text on a card, coloured by its
## [enum Kind], with an optional action button and an optional close button on the right.
## The notice is the card's slot in the stack: it is as tall as the card plus the gap under
## it, so shrinking it closes the gap. [method dismiss] fades the card out, then shrinks the
## slot and frees it. Under Reduce motion the card only fades, and the gap closes at once.
## A call's phone rattles every [constant RING_PAUSE] seconds while it shows, except under
## Reduce motion.

## The action button was pressed. The notice dismisses itself after.
signal action_pressed
## The notice started to leave, by its close button, its action, its time running out or
## [method dismiss].
signal dismissed

enum Kind { TUTORIAL, INFO, WARNING, ERROR, CALL }

## Pixels between this card and the one under it.
const GAP := 8.0
## Seconds for the card to rise in, and to fade out.
const ENTER_SECONDS := 0.3
const EXIT_SECONDS := 0.18
## Seconds for the gap to close once the card is gone.
const CLOSE_GAP_SECONDS := 0.25
## How far under its place the card starts and ends, in pixels, and how small.
const RISE := 8.0
const START_SCALE := 0.96
const END_SCALE := 0.97
## Seconds between a call's rattles, and how far the phone tips each way, in radians, on
## each swing of one: wide first, then dying out.
const RING_PAUSE := 1.6
const RING_SWINGS: Array[float] = [0.3, -0.3, 0.24, -0.18, 0.1, 0.0]
const RING_SWING_SECONDS := 0.06

const DIM := Color(0.957, 0.945, 1, 0.651)
const ICONS: Dictionary[Kind, Texture2D] = {
	Kind.TUTORIAL: preload("res://game/solar_system/icons/circle_help.svg"),
	Kind.INFO: preload("res://game/solar_system/icons/info.svg"),
	Kind.WARNING: preload("res://game/solar_system/icons/triangle_alert.svg"),
	Kind.ERROR: preload("res://game/solar_system/icons/circle_alert.svg"),
	Kind.CALL: preload("res://game/solar_system/icons/phone_call.svg"),
}
const ICON_COLORS: Dictionary[Kind, Color] = {
	Kind.TUTORIAL: DIM,
	Kind.INFO: DIM,
	Kind.WARNING: Color(0.98, 0.8, 0.38),
	Kind.ERROR: Color(0.949, 0.302, 0.4),
	Kind.CALL: Color(0.957, 0.945, 1),
}
const PANELS: Dictionary[Kind, StringName] = {
	Kind.TUTORIAL: &"NoticePanel",
	Kind.INFO: &"NoticePanel",
	Kind.WARNING: &"WarningNoticePanel",
	Kind.ERROR: &"ErrorNoticePanel",
	Kind.CALL: &"NoticePanel",
}

# From 1 while it shows to 0 once its gap has closed.
var _open := 1.0
var _kind := Kind.INFO
# Seconds until it closes by itself, or 0 for never.
var _seconds := 0.0
var _leaving := false
# Pushed while the stack was hidden: it comes in once the stack shows.
var _postponed := false
# The card's rise and fade, and the gap closing.
var _motion: Tween
var _gap: Tween
# Counts down to dismissing it, when it closes by itself.
var _life: Tween
# A call's phone rattling, on a loop.
var _ring: Tween


func _ready() -> void:
	var card := %Card as Control
	card.resized.connect(_fit)
	resized.connect(_fit)
	(%ActionButton as Button).pressed.connect(_on_action_pressed)
	(%CloseButton as Button).pressed.connect(dismiss)
	_fit()


## Sets what it says and does: its [param kind], its [param text], whether it has a close
## button, an action button reading [param action] (none when empty), and the
## [param seconds] after which it closes by itself (never when 0). Call it before it enters
## the tree.
func setup(kind: Kind, text: String, closable: bool, seconds: float, action: String) -> void:
	var icon := %Icon as TextureRect
	icon.texture = ICONS[kind]
	icon.self_modulate = ICON_COLORS[kind]
	(%Card as PanelContainer).theme_type_variation = PANELS[kind]
	(%Label as Label).text = text
	var button := %ActionButton as Button
	button.text = action
	button.visible = not action.is_empty()
	(%CloseButton as Button).visible = closable
	# Without a button the text keeps the card's full padding on the right.
	(%End as Control).visible = action.is_empty() and not closable
	_kind = kind
	_seconds = seconds


## Dismisses it the first time [param trigger] fires, such as a tutorial once the player
## does what it says or a warning once its cause is gone. Returns the notice, so it chains
## onto [method NoticeStack.push]. The connection goes with the notice when it is freed.
func close_on(trigger: Signal) -> Notice:
	trigger.connect(_dismiss_on_trigger, CONNECT_ONE_SHOT)
	return self


# Takes whatever the trigger sends.
func _dismiss_on_trigger(..._args: Array) -> void:
	dismiss()


## The text it shows.
func get_text() -> String:
	return (%Label as Label).text


## Whether it has started to leave.
func is_leaving() -> bool:
	return _leaving


## Keeps it out of sight until [method hold] lets it go, for a notice pushed while the
## stack is hidden.
func postpone() -> void:
	_postponed = true
	(%Card as Control).modulate.a = 0.0


## With [param held], stops its countdown and the phone while the stack is hidden; without,
## carries on, or brings it in if it was postponed.
func hold(held: bool) -> void:
	if not held and _postponed:
		_postponed = false
		enter()
		return
	for tween: Tween in [_life, _ring]:
		if not tween or not tween.is_valid():
			continue
		if held:
			tween.pause()
		else:
			tween.play()


## Rises the card into place from just under it, fading in.
func enter() -> void:
	var card := %Card as Control
	card.modulate.a = 0.0
	if not Settings.reduce_motion:
		card.position.y = RISE
		card.scale = Vector2.ONE * START_SCALE
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(card, ^"modulate:a", 1.0, ENTER_SECONDS)
	_motion.tween_property(card, ^"position:y", 0.0, ENTER_SECONDS)
	_motion.tween_property(card, ^"scale", Vector2.ONE, ENTER_SECONDS)
	if _seconds > 0.0:
		_life = create_tween()
		_life.tween_interval(_seconds)
		_life.tween_callback(dismiss)
	if _kind == Kind.CALL and not Settings.reduce_motion:
		_start_ring()


## Fades the card out, sinking it a little, then closes its gap and frees it. From wherever
## the card is, so it can leave while still coming in. Does nothing once it is leaving.
func dismiss() -> void:
	if _leaving:
		return
	_leaving = true
	if _life:
		_life.kill()
	(%Card as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	dismissed.emit()
	var card := %Card as Control
	var still := Settings.reduce_motion
	if _motion:
		_motion.kill()
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(card, ^"modulate:a", 0.0, EXIT_SECONDS)
	if not still:
		_motion.tween_property(card, ^"position:y", RISE * 0.75, EXIT_SECONDS)
		_motion.tween_property(card, ^"scale", Vector2.ONE * END_SCALE, EXIT_SECONDS)
	_motion.chain().tween_callback(_close_gap.bind(still))


# Rattles the phone, wide then dying out, round its middle, then rests; again and again.
func _start_ring() -> void:
	var icon := %Icon as Control
	icon.pivot_offset = icon.custom_minimum_size / 2.0
	_ring = create_tween().set_loops()
	_ring.tween_interval(RING_PAUSE)
	for swing: float in RING_SWINGS:
		_ring.tween_property(icon, ^"rotation", swing, RING_SWING_SECONDS).set_trans(
			Tween.TRANS_SINE
		)


func _close_gap(still: bool) -> void:
	if still:
		queue_free()
		return
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_open, _open, 0.0, CLOSE_GAP_SECONDS)
	_gap.tween_callback(queue_free)


func _set_open(open: float) -> void:
	_open = open
	_fit()


# Sizes the slot to the card and its gap, and centres the card in it, scaling from its
# bottom middle.
func _fit() -> void:
	var card := %Card as Control
	custom_minimum_size = Vector2(card.size.x, (card.size.y + GAP) * _open)
	card.position.x = (size.x - card.size.x) / 2.0
	card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)


func _on_action_pressed() -> void:
	action_pressed.emit()
	dismiss()
