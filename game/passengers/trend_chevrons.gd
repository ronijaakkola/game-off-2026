class_name TrendChevrons
extends Control
## A row of [member count] chevrons, each as tall as the control, pointing right while
## [member rising] and left otherwise, in [member color]: how fast something is heading
## which way, as on a passenger's happiness bar. Draws nothing at a count of 0. Its
## [method get_width] is how wide the row is, for whoever places it.
## On a bar, [method follow] sets the count from a trend every frame, fades the row in and
## out, and rides the end of the bar's fill: inside it at its end, or just past it once
## the fill is too short to hold them.

const CHEVRON := preload("res://game/passengers/icons/chevron_right.svg")
## How far each chevron starts from the one before, as a share of its own width: 1 leaves
## the gap the stroke's round caps leave, so each one reads at a few pixels tall.
const STEP_RATIO := 1.0
## How much the trend must cover, either way, for each more chevron, and how far under its
## step a chevron already shown may drop before it goes, so a trend near a step doesn't
## flicker.
const STEPS: Array[float] = [1.5, 8.0, 20.0]
const MARGIN := 1.0
## Their colour inside the fill, dark so they read on every fill colour.
const INSIDE_COLOR := Color(0.1, 0.06, 0.18, 0.7)
## Pixels between the chevrons and the fill's end, and between them and the bar's top and
## bottom.
const PAD := 2.0
const INSET := 1.0
## Seconds they take to fade in or out.
const FADE_SECONDS := 0.2

## How many chevrons it draws.
var count := 0:
	set(value):
		count = value
		queue_redraw()
## Whether they point right. Off, they point left.
var rising := true:
	set(value):
		rising = value
		queue_redraw()
var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()

# How many chevrons the trend calls for, which way, and how far they have faded in. They
# keep their count while they fade out.
var _wanted := 0
var _wanted_rising := true
var _alpha := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How wide the row of [param chevrons] chevrons is at the control's height: [member count]
## by default.
func get_width(chevrons := -1) -> float:
	var n := count if chevrons < 0 else chevrons
	if n <= 0:
		return 0.0
	var one := _chevron_width()
	return one + one * STEP_RATIO * (n - 1)


## Follows [param trend] for [param delta] seconds on [param bar], the [ProgressBar] it is
## a child of, whose fill is [param fill_color]: as many chevrons as the trend calls for,
## fading in and out, at the fill's end.
func follow(trend: float, delta: float, bar: ProgressBar, fill_color: Color) -> void:
	var up := trend > 0.0
	# A chevron shown holds until the trend drops MARGIN under its step; a turn starts
	# afresh.
	var shown := _wanted if up == _wanted_rising else 0
	var wanted := 0
	for i: int in STEPS.size():
		var step := STEPS[i] - (MARGIN if i < shown else 0.0)
		if absf(trend) >= step:
			wanted = i + 1
	_wanted = wanted
	if wanted > 0:
		_wanted_rising = up
	_alpha = move_toward(_alpha, 1.0 if wanted > 0 else 0.0, delta / FADE_SECONDS)
	if wanted > 0:
		count = wanted
		rising = up
	elif _alpha <= 0.0:
		count = 0
	modulate.a = _alpha
	_place(bar, fill_color)


func _draw() -> void:
	if count <= 0:
		return
	var one := Vector2(_chevron_width(), size.y)
	var step := one.x * STEP_RATIO
	if not rising:
		# Mirrored about the row's middle, so a falling row fills the same box.
		draw_set_transform(Vector2(get_width(), 0.0), 0.0, Vector2(-1.0, 1.0))
	for i: int in count:
		draw_texture_rect(CHEVRON, Rect2(Vector2(step * i, 0.0), one), false, color)


func _chevron_width() -> float:
	var texture := CHEVRON.get_size()
	return size.y * texture.x / texture.y


# Puts the row inside [param bar]'s fill at its end, or just past its end when it is too
# short to hold them, in [param fill_color] there.
func _place(bar: ProgressBar, fill_color: Color) -> void:
	var height := bar.size.y - INSET * 2.0
	size = Vector2(size.x, height)
	var width := get_width()
	size = Vector2(width, height)
	var end := bar.size.x * bar.value / bar.max_value
	var x := end - PAD - width
	var shade := INSIDE_COLOR
	if x < PAD:
		x = end + PAD
		shade = fill_color
	position = Vector2(x, INSET)
	color = shade
