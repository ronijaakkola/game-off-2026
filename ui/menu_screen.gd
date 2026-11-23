class_name MenuScreen
extends Control
## A screen a menu opens over itself, such as Settings or Controls. A menu instances it
## hidden and calls [method open], which hides the menu's own controls while it shows. Back
## ([code]%BackButton[/code]) or Esc hides it again and brings them back, with focus on the
## control that opened it.
## Given the menu's items, the change is staggered: the menu's items slide left and fade
## one after another, then the screen's slide in from the right the same way; going back,
## the screen's slide right and fade, then the menu's come in from the left. A transition
## started midway turns each item round from where it is. Under Reduce motion they only
## fade. Without the menu's items, as in the pause menu, the screen swaps in and out at once.

## Seconds each item takes to leave, and between one item leaving and the next.
const LEAVE_SECONDS := 0.14
const LEAVE_STAGGER := 0.03
## Seconds each item takes to come in, and between one item coming in and the next.
const ENTER_SECONDS := 0.32
const ENTER_STAGGER := 0.05
## Pixels an item slides as it leaves or comes in.
const SHIFT := 32.0
# The meta holding where an item sits in its container while it slides.
const REST := &"menu_screen_rest"
# Seconds the menu's rows wait at the least on the way back, so the menu lays out first.
const LAYOUT_SECONDS := 0.05
# How faint the rows draw for the warm-up frame, unseen but drawn: a row at zero alpha isn't
# drawn at all.
const WARM_ALPHA := 0.01

# One transition at a time across every screen, since a menu's items can be on their way
# back from one screen while the player opens the next.
static var _motion: Tween

## Seconds the next items wait to come in, from the screen showing as it opens, or from it
## hiding as it closes: the campaign screen waits for the background to pan.
@export var enter_delay := 0.0

var _covered: Control
var _covered_rows := Callable()
var _covered_items: Array[Control] = []
var _opener: Control
var _closing := false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	(%BackButton as Button).pressed.connect(close)
	_warm_up.call_deferred()


## Whether the screen is open, or still going back.
func is_open() -> bool:
	return _covered != null


## Shows the screen, its first control focused. [param covered] holds the opening menu's
## controls, hidden until the screen hides. [param covered_rows] returns its rows top to
## bottom, which stagger out and back in; it is asked again on the way back, since the rows
## shown can change while the screen is open. Does nothing while it's already open, so the
## focus it hands back stays the opener's.
func open(covered: Control, covered_rows := Callable()) -> void:
	if _covered != null:
		return
	_covered = covered
	_covered_rows = covered_rows
	_opener = get_viewport().gui_get_focus_owner()
	_opening()
	if not covered_rows.is_valid():
		_covered.hide()
		show()
		_first_control().grab_focus()
		return
	var items := _items()
	for item: Control in items:
		item.modulate.a = 0.0
	# Takes the clicks meant for the menu's items while they leave.
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	_first_control().grab_focus()
	_covered_items = covered_rows.call()
	var motion := _start_motion()
	var left := _stagger(motion, _covered_items, -1.0, 0.0, false)
	motion.tween_callback(covered.hide).set_delay(left)
	var done := _stagger(motion, items, 1.0, maxf(left, _enter_delay()), true)
	motion.tween_callback(set_mouse_filter.bind(Control.MOUSE_FILTER_IGNORE)).set_delay(done)


## Hides the screen as Back does: staggered out, then the menu's items back in, when it was
## opened with them; else at once.
func close() -> void:
	if _covered == null or _closing:
		return
	if not _covered_rows.is_valid():
		hide()
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var items := _items()
	var covered_items: Array[Control] = _covered_rows.call()
	# A row gone since it left shows again whole when it next shows. With the menu's rows
	# all gone, one shown since starts gone too, rather than popping in.
	for row: Control in _covered_items:
		if row not in covered_items:
			_settle([row])
	if not _covered.visible:
		for row: Control in covered_items:
			row.modulate.a = 0.0
	_covered_items = covered_items
	var motion := _start_motion()
	var left := _stagger(motion, items, 1.0, 0.0, false)
	motion.tween_callback(hide).set_delay(left)
	# The screen hides once its items have left, so the wait starts then.
	var wait := maxf(_enter_delay(), LAYOUT_SECONDS)
	var done := _stagger(motion, covered_items, -1.0, left + wait, true)
	motion.tween_callback(_settle.bind(items)).set_delay(done)


## Where [param item] sits in its container, even while it slides.
static func rest_position(item: Control) -> Vector2:
	return item.get_meta(REST, item.position)


# Draws the rows once, faint, for a frame as the menu loads, so a shader they draw with (the
# cards' pictures, the glass) compiles then rather than as the rows fade in, where on the web
# its first draw stalls a frame long enough for the stagger to skip ahead. Only before it
# first opens; under a hidden menu, such as the pause menu, it draws nothing.
func _warm_up() -> void:
	if visible or is_open():
		return
	var items := _items()
	for item: Control in items:
		item.modulate.a = WARM_ALPHA
	# Unseen, it takes no clicks meant for the menu under it.
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	show()
	# The frame it shows in is drawn before the next one starts.
	await get_tree().process_frame
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if is_open():
		return
	hide()
	for item: Control in items:
		item.modulate.a = 1.0


## Called as the screen opens, before it shows.
func _opening() -> void:
	pass


## The control focused as the screen opens.
func _first_control() -> Control:
	return %BackButton


## The rows that stagger in, top to bottom: the header, then each card shown.
func _items() -> Array[Control]:
	var items: Array[Control] = [%Header]
	for card: Control in %Cards.get_children():
		if card.visible:
			items.append(card)
	return items


func _enter_delay() -> float:
	return 0.0 if Settings.reduce_motion else enter_delay


func _start_motion() -> Tween:
	if _motion:
		_motion.kill()
	_motion = create_tween().set_parallel()
	return _motion


# Moves [param items] one after another from where each is, starting [param delay] in, in
# to their places when [param entering] or else out, sliding to the [param side] (1 right,
# -1 left). Returns when the last one ends.
func _stagger(
	motion: Tween, items: Array[Control], side: float, delay: float, entering: bool
) -> float:
	var seconds := ENTER_SECONDS if entering else LEAVE_SECONDS
	var stagger := ENTER_STAGGER if entering else LEAVE_STAGGER
	var shift := 0.0 if Settings.reduce_motion else side * SHIFT
	var end := delay
	for i: int in items.size():
		var item := items[i]
		var away := 1.0 - item.modulate.a
		var to := 0.0 if entering else 1.0
		var start := delay + i * stagger
		(
			motion
			. tween_method(_place.bind(item, shift), away, to, seconds)
			. set_delay(start)
			. set_ease(Tween.EASE_OUT)
			. set_trans(Tween.TRANS_EXPO if entering else Tween.TRANS_CUBIC)
		)
		end = start + seconds
	return end


# Puts [param item] [param away] of the way out (0 in place, 1 gone), [param shift]
# pixels across and faded. Its place is kept from the first step, since the container
# would put it back on a re-sort. Gone, it goes back to its place unseen, so the container
# can lay it out anew before it comes back.
func _place(away: float, item: Control, shift: float) -> void:
	if not is_instance_valid(item):
		return
	if not item.has_meta(REST):
		item.set_meta(REST, item.position)
	item.position = rest_position(item) + Vector2(shift * away, 0.0)
	item.modulate.a = 1.0 - away
	if away == 0.0:
		_settle([item])
	elif away == 1.0:
		_settle([item])
		item.modulate.a = 0.0


# Puts [param items] back in place and fully shown.
func _settle(items: Array[Control]) -> void:
	for item: Control in items:
		if not is_instance_valid(item):
			continue
		if item.has_meta(REST):
			item.position = item.get_meta(REST)
			item.remove_meta(REST)
			var container := item.get_parent() as Container
			if container:
				container.queue_sort()
		item.modulate.a = 1.0


# Hidden by Back, Esc or the menu that opened it, so it hands focus back here. Hidden from
# outside midway, as the pause menu's Resume does, everything snaps back in place.
func _on_visibility_changed() -> void:
	if visible or _covered == null:
		return
	if not _closing:
		if _motion:
			_motion.kill()
		_settle(_items())
		_settle(_covered_items)
	_closing = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_covered.show()
	_covered = null
	_covered_rows = Callable()
	_covered_items = []
	if is_instance_valid(_opener):
		_opener.grab_focus()


# Esc goes back, like the Back button, and stops there: the pause menu under the screen
# also closes on Esc, which would resume the game.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
