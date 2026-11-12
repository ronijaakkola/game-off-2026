class_name Tooltip
extends PanelContainer
## A small dark card naming the thing under the pointer: a [member title] and, when it
## helps, one [member sentence], and under them, where the caller gives one, an
## [member extra] row such as a cost. It belongs to its [member target]: once the pointer has
## rested on that for [member rest_seconds] it opens, or as the pointer arrives where that is
## 0, centred on the target and [member gap] pixels from it, and it closes when the pointer
## leaves. It comes from the target: it
## slides out from it into place, growing out of the edge that faces it while fading in.
## Closing is simpler and a little faster: it fades and shrinks back where it is. A pointer
## that leaves while it opens, or comes back while it closes, turns it round from where it
## is. Under Reduce motion it only fades. When the game pauses it closes at once.
## Going from one tooltip to the next skips the wait and the motion: for a moment after one
## closes, another target the pointer reaches shows its card at once, and the one still
## closing goes at once too, so reading along a row never waits.
## It is top-level, so a Container holding it gives it no room, and it stays on screen:
## near an edge it moves along its target only as far as it must.

## Which edge of the target it sits at. Beside is to the right where it fits on screen,
## else to the left, centred on the target's height: for targets in a grid read from above,
## such as the research trees, where a card below would cover what comes next.
enum Side { BELOW = 0, ABOVE = 1, BESIDE = 2 }

## Seconds it takes to open, and to close: leaving is the faster of the two.
const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.1
## Its scale while closed, which it grows from and shrinks to.
const CLOSED_SCALE := 0.94
## How far toward the target it starts, in pixels, which it slides out from as it opens.
const SLIDE_PIXELS := 6.0
## Seconds after a card starts to close in which the next one opens at once.
const WARM_SECONDS := 0.3
## The least room it leaves to the screen's side edges, in pixels.
const SCREEN_MARGIN := 8.0
## The most room the sentence takes before it wraps, in pixels.
const MAX_SENTENCE_WIDTH := 184.0

# When the last card to close did, in milliseconds since the game started, and which it
# was. Shared by every tooltip.
static var _closed_at := -1000000
static var _leaving: Tooltip

## The control the pointer rests on. It needs a [member Control.mouse_filter] that takes
## the pointer.
@export var target: Control
@export var title := "":
	set(value):
		title = value
		if is_node_ready():
			_show_text()
## Running text under the title. Empty leaves the title alone, on a slimmer card.
@export_multiline var sentence := "":
	set(value):
		sentence = value
		if is_node_ready():
			_show_text()
@export var side := Side.BELOW
## Pixels between the target's edge and the card.
@export var gap := 8.0
## Seconds the pointer rests on the target before the card opens. 0 opens it as the pointer
## arrives, for a grid of targets read one after another, such as the research trees.
@export var rest_seconds := 0.3

## A row of the caller's under the sentence, such as a cost, or null for none. Set it
## before the card opens; changing it while open resizes the card.
var extra: Control:
	set(value):
		var rows := get_node(^"Rows") as VBoxContainer
		if extra and extra.get_parent() == rows:
			rows.remove_child(extra)
			extra.queue_free()
		extra = value
		if extra:
			extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rows.add_child(extra)
		if _open:
			_fit()

var _open := false
# How far toward the target it still is: 1 before it opens, 0 in place.
var _slide := 1.0
# The fade and the scale, and the slide as it opens, together.
var _motion: Tween


func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * CLOSED_SCALE
	set_process(false)
	_show_text()
	if rest_seconds > 0.0:
		(%RestTimer as Timer).wait_time = rest_seconds
	(%RestTimer as Timer).timeout.connect(open)
	if target:
		target.mouse_entered.connect(_on_target_entered)
		target.mouse_exited.connect(close)
		target.gui_input.connect(_on_target_input)


func _process(_delta: float) -> void:
	_place()


# Paused, its motion would stop half-way and leave it showing, so it goes at once.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and visible:
		(%RestTimer as Timer).stop()
		_open = false
		_motion.kill()
		modulate.a = 0.0
		scale = Vector2.ONE * CLOSED_SCALE
		_on_closed()


## Opens the card at its target, with no motion when [param at_once]. Nothing happens
## while it is open.
func open(at_once := false) -> void:
	if _open:
		return
	_open = true
	_fit()
	show()
	set_process(true)
	_animate(1.0, 1.0, OPEN_SECONDS)
	if not Settings.reduce_motion:
		_motion.tween_method(_set_slide, _slide, 0.0, OPEN_SECONDS)
	if at_once:
		_motion.custom_step(OPEN_SECONDS)


## Closes the card, and stops it opening until the pointer rests on the target again.
func close() -> void:
	(%RestTimer as Timer).stop()
	if not _open:
		return
	_open = false
	_closed_at = Time.get_ticks_msec()
	_leaving = self
	_animate(0.0, CLOSED_SCALE, CLOSE_SECONDS)
	_motion.chain().tween_callback(_on_closed)


func _on_closed() -> void:
	hide()
	set_process(false)
	_slide = 1.0


# The pointer reached the target. Straight from another tooltip, the card shows at once
# and the other one, if still closing, is gone at once. Straight back to its own target,
# it opens again from where it is. Otherwise the wait starts, if it has one.
func _on_target_entered() -> void:
	if Time.get_ticks_msec() - _closed_at > WARM_SECONDS * 1000.0:
		if rest_seconds > 0.0:
			(%RestTimer as Timer).start()
		else:
			open()
		return
	var from_another := is_instance_valid(_leaving) and _leaving != self
	if from_another and not _leaving._open and _leaving._motion.is_running():
		_leaving._motion.custom_step(CLOSE_SECONDS)
	open(from_another)


# The pointer moved on the target: it hasn't rested yet, so the wait starts over.
func _on_target_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _open and rest_seconds > 0.0:
		(%RestTimer as Timer).start()


# Both run from where they are, so turning round mid-way never jumps. The movement eases
# out hard; the fade more gently, or it would be over before the movement shows.
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


func _show_text() -> void:
	(%NameLabel as Label).text = title
	var label := %SentenceLabel as Label
	label.text = sentence
	label.visible = not sentence.is_empty()
	theme_type_variation = &"TooltipCardPanel" if label.visible else &"TooltipNamePanel"
	# A wrapping label asks for no width, so it gets what its text needs, up to the most.
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var width := font.get_string_size(sentence, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label.custom_minimum_size.x = minf(ceilf(width), MAX_SENTENCE_WIDTH)
	if _open:
		_fit()


# Sizes the card to what it holds. Hidden, the sentence was never laid out: it wraps to the
# width it has, so it gets its width here, and the card's size follows from the lines that
# makes.
func _fit() -> void:
	var label := %SentenceLabel as Label
	label.size.x = label.custom_minimum_size.x
	label.update_minimum_size()
	reset_size()
	_place()


# Centred on the target, or as near as the screen's edges let it, on whole pixels
# once in place so the text stays sharp, slid toward the target by _slide, and scaling
# from the point of the edge facing the target that is at the target's centre.
func _place() -> void:
	if not target:
		return
	var rect := target.get_global_rect()
	if side == Side.BESIDE:
		_place_beside(rect)
		return
	var below := side == Side.BELOW
	var top := rect.end.y + gap if below else rect.position.y - gap - size.y
	var toward := -SLIDE_PIXELS if below else SLIDE_PIXELS
	# Its position, not its global position: that one is where its scaled corner shows,
	# which moves sideways as it grows. Top-level, the two are in the same space.
	var centre := rect.get_center().x
	var most := get_viewport_rect().size.x - size.x - SCREEN_MARGIN
	var left := clampf(centre - size.x * 0.5, minf(SCREEN_MARGIN, most), most)
	position = Vector2(left, top).round()
	pivot_offset = Vector2(centre - position.x, 0.0 if below else size.y)
	position.y += toward * _slide


# Right of the target where the card fits on screen, else left of it, centred on its height
# as far as the screen's top and bottom let it, scaling from the facing edge.
func _place_beside(rect: Rect2) -> void:
	var screen := get_viewport_rect().size
	var right := rect.end.x + gap + size.x <= screen.x - SCREEN_MARGIN
	var left := rect.end.x + gap if right else rect.position.x - gap - size.x
	var centre := rect.get_center().y
	var most := screen.y - size.y - SCREEN_MARGIN
	var top := clampf(centre - size.y * 0.5, minf(SCREEN_MARGIN, most), most)
	position = Vector2(left, top).round()
	pivot_offset = Vector2(0.0 if right else size.x, centre - position.y)
	position.x += (-SLIDE_PIXELS if right else SLIDE_PIXELS) * _slide
