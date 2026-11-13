class_name ButtonFeel
extends Node
## How a plain [Button] feels under the pointer. Every one that enters the tree dips a
## little while it is held and springs back when let go, about the point it was pressed
## at, so the pointer never ends up off a button that shrank under it. A button asked to
## with [method wiggle_on_hover] also tips side to side once as the pointer arrives.
## Toggles don't move, nor does a button in the [constant OWN_PRESS] group, which shows a
## press its own way. It runs while the game is paused, for the pause menu. Under Reduce
## motion nothing moves.

## The group of a button that shows a press its own way, so it gets no dip.
const OWN_PRESS := &"own_press"
## How small a held button gets.
const PRESS_SCALE := 0.96
## The spring that moves the scale: how hard it pulls, and how much it resists. Low
## resistance, so a button let go ends a touch over its size before it settles.
const PRESS_STIFFNESS := 700.0
const PRESS_DAMPING := 24.0
## How fast a wiggle starts turning, in radians a second, and the spring that brings the
## button back level.
const WIGGLE_KICK := 0.9
const WIGGLE_STIFFNESS := 500.0
const WIGGLE_DAMPING := 14.0
# The longest step the springs take, in seconds, so a slow frame can't throw them.
const MAX_STEP := 1.0 / 30.0
# How close to rest, in scale, radians and their speeds, counts as settled.
const REST := 0.0005


class Motion:
	var held := false
	var scale := 1.0
	var scale_speed := 0.0
	var turn := 0.0
	var turn_speed := 0.0


# The buttons in motion, by instance id, so one freed mid-motion is only forgotten.
var _moving: Dictionary[int, Motion] = {}
# Which way the next wiggle tips first.
var _kick_sign := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	var step := minf(delta, MAX_STEP)
	for id: int in _moving.keys():
		var button := instance_from_id(id) as Button
		if not button:
			_moving.erase(id)
			continue
		var motion := _moving[id]
		# Hidden or turned off while held, it may never see the release.
		if not button.is_visible_in_tree() or button.disabled:
			motion.held = false
		var target := PRESS_SCALE if motion.held else 1.0
		var pull := (target - motion.scale) * PRESS_STIFFNESS
		motion.scale_speed += (pull - motion.scale_speed * PRESS_DAMPING) * step
		motion.scale += motion.scale_speed * step
		var level := -motion.turn * WIGGLE_STIFFNESS
		motion.turn_speed += (level - motion.turn_speed * WIGGLE_DAMPING) * step
		motion.turn += motion.turn_speed * step
		if not motion.held and _is_at_rest(motion):
			_moving.erase(id)
			button.scale = Vector2.ONE
			button.rotation = 0.0
			button.pivot_offset = Vector2.ZERO
			continue
		# Every frame, since a container that sorts its children puts both back.
		button.scale = Vector2.ONE * motion.scale
		button.rotation = motion.turn


## Tips [param button] side to side once, dying out, each time the pointer comes over it.
func wiggle_on_hover(button: Button) -> void:
	button.mouse_entered.connect(_on_hovered.bind(button))


func _is_at_rest(motion: Motion) -> bool:
	return (
		absf(motion.scale - 1.0) < REST
		and absf(motion.scale_speed) < REST
		and absf(motion.turn) < REST
		and absf(motion.turn_speed) < REST
	)


func _motion_of(button: Button) -> Motion:
	var id := button.get_instance_id()
	if not _moving.has(id):
		_moving[id] = Motion.new()
		button.pivot_offset_ratio = Vector2(0.5, 0.5)
		button.pivot_offset = Vector2.ZERO
	return _moving[id]


func _on_node_added(node: Node) -> void:
	var button := node as Button
	if not button or button is CheckButton or button is CheckBox:
		return
	var down := _on_button_down.bind(button)
	if button.button_down.is_connected(down):
		return
	button.button_down.connect(down)
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_down(button: Button) -> void:
	if Settings.reduce_motion or button.is_in_group(OWN_PRESS):
		return
	var motion := _motion_of(button)
	motion.held = true
	# About the pointer, so the button can't shrink out from under it and miss the release.
	var pointer := button.get_local_mouse_position()
	if Rect2(Vector2.ZERO, button.size).has_point(pointer):
		button.pivot_offset = pointer - button.size * 0.5


func _on_button_up(button: Button) -> void:
	var motion: Motion = _moving.get(button.get_instance_id())
	if motion:
		motion.held = false


func _on_hovered(button: Button) -> void:
	if Settings.reduce_motion or button.disabled:
		return
	# One still moving is left alone: a tipped button's edge can pass under a pointer that
	# stays still, and each pass would start it again.
	if _moving.has(button.get_instance_id()):
		return
	_motion_of(button).turn_speed = WIGGLE_KICK * _kick_sign
	_kick_sign = -_kick_sign
