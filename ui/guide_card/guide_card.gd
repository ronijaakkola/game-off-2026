class_name GuideCard
extends PanelContainer
## A solid dark card that points at something on screen and says what to do with it, for
## the tutorial and for a feature met during play. A [member title], one to three lines of
## [member text], and a notch on the edge facing the target, pointing at its middle.
## A [constant Kind.TUTORIAL_STEP] shows step dots for how far along the tutorial is, when
## [member step_count] is more than one, and
## goes once its owner sees the player did what it says. A [constant Kind.FEATURE_HINT]
## shows a "Game paused" tag and a Got it button, which emits [signal acknowledged]; its
## owner pauses and resumes the game. A tutorial step with [member got_it] has the Got it
## button too, beside its step dots. It works while the game is paused.
## It sits on the [member side] of its target that its owner gives, follows the target as
## it moves, stays [constant SCREEN_MARGIN] pixels inside the screen, and slides its notch
## along its edge to stay on the target. It is top-level, so a Container holding it gives
## it no room. Only the Got it button takes the pointer.
## It opens and closes as a [Tooltip] does, with the tooltip's own timings: opening, it
## slides out from the target into place while fading in and growing out of its notch;
## closing, it only fades and shrinks back. Either turns round from where it is. Just
## after it opens, its step dots move on from the step it showed last to [member step].
## Under Reduce motion it only fades, and the dots change at once.

## The player pressed Got it.
signal acknowledged

enum Kind { TUTORIAL_STEP = 0, FEATURE_HINT = 1 }
## Which side of the target the card sits on. The notch is on the edge facing it.
enum Side { BELOW = 0, ABOVE = 1, LEFT = 2, RIGHT = 3 }

## The card's width, in pixels. It grows downward to fit its text.
const WIDTH := 256.0
## The notch: how wide its base is and how far its tip sticks out, in pixels.
const NOTCH_WIDTH := 14.0
const NOTCH_LENGTH := 7.0
## Pixels from the target's edge to the notch's tip: room for the target's ring and 6 px.
const TIP_GAP := 12.0
## The least room between the notch's middle and a corner of the card, in pixels.
const NOTCH_CORNER_MARGIN := 16.0
## The least room the card leaves to every edge of the screen, in pixels.
const SCREEN_MARGIN := 12.0
## A beat after the card is in, before the step dots move on, in seconds.
const DOTS_DELAY := 0.1
## Seconds the step dots take to move on to the next step.
const DOTS_SECONDS := 0.3
## Step dots: a dot's size, the current step's, and the room between two.
const DOT_SIZE := 6.0
const CURRENT_DOT_SIZE := 8.0
const DOT_GAP := 4.0
const DOT_DONE := Color(0.957, 0.945, 1, 0.651)
const DOT_CURRENT := Color(0.957, 0.945, 1, 1)
const DOT_TO_COME := Color(1, 1, 1, 0.141)

@export var kind := Kind.TUTORIAL_STEP:
	set(value):
		kind = value
		if is_node_ready():
			_show_content()
@export var title := "":
	set(value):
		title = value
		if is_node_ready():
			_show_content()
@export_multiline var text := "":
	set(value):
		text = value
		if is_node_ready():
			_show_content()
## Whether a tutorial step has the Got it button. A feature hint always has it.
@export var got_it := false:
	set(value):
		got_it = value
		if is_node_ready():
			_show_content()
@export var side := Side.BELOW
## A control to point at. While set, the card follows it; otherwise it points at
## [member target_rect].
@export var target: Control
## Which tutorial step this is, from 0, and how many there are.
@export var step := 0:
	set(value):
		step = value
		if is_node_ready():
			_show_content()
		if _open:
			_move_dots_on(0.0)
@export var step_count := 1:
	set(value):
		step_count = value
		if is_node_ready():
			_show_content()

## The target on screen, in the viewport's pixels, when [member target] is null, such as a
## planet's outline. Its owner updates it as the target moves.
var target_rect := Rect2()

# Where along the facing edge the notch's middle sits, from the edge's start, in pixels.
var _notch_at := WIDTH * 0.5
var _open := false
# How far toward the target it still is: 1 before it opens, 0 in place.
var _slide := 1.0
# The fade and the scale, and the slide as it opens, together.
var _motion: Tween
# The step the dots show, between two steps while they move on; below 0 before they
# first show.
var _dots_at := -1.0
var _dots: Tween


func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * Tooltip.CLOSED_SCALE
	set_process(false)
	(%StepDots as Control).draw.connect(_draw_step_dots)
	(%GotItButton as Button).pressed.connect(_on_got_it_pressed)
	_show_content()


func _process(_delta: float) -> void:
	_place()


# The notch, over the card's border, its two sides in the border's colour.
func _draw() -> void:
	var box := get_theme_stylebox(&"panel") as StyleBoxFlat
	var half := NOTCH_WIDTH * 0.5
	# In the card's space with the facing edge along y = 0, outside toward -y. A point
	# (along, out) maps to the card's own pixels through _edge_point.
	var base_in := box.border_width_top + 0.5
	var fill := PackedVector2Array(
		[
			_edge_point(_notch_at - half, -base_in),
			_edge_point(_notch_at, NOTCH_LENGTH),
			_edge_point(_notch_at + half, -base_in),
		]
	)
	draw_colored_polygon(fill, box.bg_color)
	var outline := PackedVector2Array(
		[
			_edge_point(_notch_at - half, -0.5),
			_edge_point(_notch_at, NOTCH_LENGTH - 0.5),
			_edge_point(_notch_at + half, -0.5),
		]
	)
	draw_polyline(outline, box.border_color, 1.0, true)


## Opens the card at its target, then moves its step dots on. Nothing happens while it
## is open.
func open() -> void:
	if _open:
		return
	_open = true
	reset_size()
	_place()
	show()
	set_process(true)
	_animate(1.0, 1.0, Tooltip.OPEN_SECONDS)
	if not Settings.reduce_motion:
		_motion.tween_method(_set_slide, _slide, 0.0, Tooltip.OPEN_SECONDS)
	_move_dots_on(Tooltip.OPEN_SECONDS + DOTS_DELAY)


## Closes the card where it is.
func close() -> void:
	if not _open:
		return
	_open = false
	_animate(0.0, Tooltip.CLOSED_SCALE, Tooltip.CLOSE_SECONDS)
	_motion.chain().tween_callback(_on_closed)


# Only once: a press while it closes is too late.
func _on_got_it_pressed() -> void:
	if _open:
		acknowledged.emit()


func _on_closed() -> void:
	hide()
	set_process(false)
	_slide = 1.0


# As Tooltip's: both run from where they are, so turning round mid-way never jumps. The
# movement eases out hard; the fade more gently, or it would be over before the movement
# shows.
func _animate(alpha: float, to_scale: float, seconds: float) -> void:
	if _motion:
		_motion.kill()
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, ^"modulate:a", alpha, seconds).set_trans(Tween.TRANS_QUAD)
	if Settings.reduce_motion:
		scale = Vector2.ONE
		_set_slide(0.0)
	else:
		_motion.tween_property(self, ^"scale", Vector2.ONE * to_scale, seconds)


func _set_slide(value: float) -> void:
	_slide = value
	_place()


# From the step the dots showed last to this one, after [param delay] seconds. The first
# time, from the step before, so a card that opens on a later step still shows the
# tutorial moving on.
func _move_dots_on(delay: float) -> void:
	if _dots:
		_dots.kill()
	if _dots_at < 0.0:
		_set_dots_at(maxf(step - 1.0, 0.0))
	if Settings.reduce_motion or is_equal_approx(_dots_at, step):
		_set_dots_at(step)
		return
	_dots = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_dots.tween_interval(delay)
	_dots.tween_method(_set_dots_at, _dots_at, float(step), DOTS_SECONDS)


func _set_dots_at(value: float) -> void:
	_dots_at = value
	(%StepDots as Control).queue_redraw()


func _show_content() -> void:
	var feature := kind == Kind.FEATURE_HINT
	(%TitleLabel as Label).text = title
	(%BodyLabel as Label).text = text
	(%PausedTag as Control).visible = feature
	(%GotItButton as Control).visible = feature or got_it
	var dots := %StepDots as Control
	dots.visible = not feature and step_count > 1
	(%Footer as Control).visible = dots.visible or feature or got_it
	dots.custom_minimum_size.x = CURRENT_DOT_SIZE + (step_count - 1) * (DOT_SIZE + DOT_GAP)
	dots.queue_redraw()
	reset_size()


# One dot a step: the current one larger and white, those done dim, those to come faint.
# Between two steps, the two dots share the current one's size and colour by how near
# each is, so the row stays as wide and every dot moves smoothly.
func _draw_step_dots() -> void:
	var dots := %StepDots as Control
	var at := maxf(_dots_at, 0.0)
	var x := 0.0
	for index: int in step_count:
		var current := clampf(1.0 - absf(index - at), 0.0, 1.0)
		var diameter := lerpf(DOT_SIZE, CURRENT_DOT_SIZE, current)
		var colour := (DOT_DONE if index < at else DOT_TO_COME).lerp(DOT_CURRENT, current)
		var centre := Vector2(x + diameter * 0.5, dots.size.y * 0.5)
		dots.draw_circle(centre, diameter * 0.5, colour, true, -1.0, true)
		x += diameter + DOT_GAP


# Beside the target on its side, the notch's tip TIP_GAP from it and centred on it, or as
# near as the screen's edges let it; then the notch slides to stay on the target.
func _place() -> void:
	var rect := target.get_global_rect() if target else target_rect
	var screen := get_viewport_rect().size
	var centre := rect.get_center()
	var away := TIP_GAP + NOTCH_LENGTH
	var at := Vector2.ZERO
	match side:
		Side.BELOW:
			at = Vector2(centre.x - size.x * 0.5, rect.end.y + away)
		Side.ABOVE:
			at = Vector2(centre.x - size.x * 0.5, rect.position.y - away - size.y)
		Side.LEFT:
			at = Vector2(rect.position.x - away - size.x, centre.y - size.y * 0.5)
		Side.RIGHT:
			at = Vector2(rect.end.x + away, centre.y - size.y * 0.5)
	var most := screen - size - Vector2.ONE * SCREEN_MARGIN
	at = at.clamp(Vector2.ONE * SCREEN_MARGIN, most.max(Vector2.ONE * SCREEN_MARGIN))
	position = at.round()
	var vertical := side in [Side.BELOW, Side.ABOVE]
	var along := centre.x - position.x if vertical else centre.y - position.y
	var length := size.x if vertical else size.y
	_notch_at = clampf(along, NOTCH_CORNER_MARGIN, length - NOTCH_CORNER_MARGIN)
	# It grows out of the notch's tip, and slides from the target.
	pivot_offset = _edge_point(_notch_at, NOTCH_LENGTH)
	position += _edge_point(0.0, Tooltip.SLIDE_PIXELS * _slide) - _edge_point(0.0, 0.0)
	queue_redraw()


# A point given along the facing edge and out from it, in the card's own pixels.
func _edge_point(along: float, out: float) -> Vector2:
	match side:
		Side.BELOW:
			return Vector2(along, -out)
		Side.ABOVE:
			return Vector2(along, size.y + out)
		Side.LEFT:
			return Vector2(size.x + out, along)
	return Vector2(-out, along)
