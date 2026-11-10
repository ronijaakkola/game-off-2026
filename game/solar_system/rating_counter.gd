class_name RatingCounter
extends HBoxContainer
## The player's recent rating in the resource bar: a star and the mean of the last ratings
## passengers gave on getting off ([method Ledger.get_recent_rating]), to one decimal, or a
## dash before the first, in the room a rating takes so the bar keeps its width. Like the
## credits, ratings collect first: the change they make to the average shows in a gain floating
## under the bar ("+0.2" in green, "-0.3" in red), which pops with each rating. Once [method
## commit] is called, after a short delay the average moves to its new value while the gain
## fades out drifting upward. It shows the ratings of its [member ledger] and animates each one
## the ledger signals; it keeps no ratings of its own. The ledger already counts every rating;
## only what shows waits. The pointer over it shows who that rating attracts ([RatingBand]).

## What shows before anyone has rated a ride.
const NO_RATING := "–"
## Seconds from [method commit] to the average starting to move, and how long it takes.
const COMMIT_DELAY := 0.25
const COUNT_SECONDS := 0.5
## How much bigger a number pops, and the seconds up and back down.
const POP_SCALE := 1.35
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14
## Seconds the gain takes to fade out, and how far up it drifts meanwhile, in pixels.
const FADE_OUT_SECONDS := 0.6
const RISE_PIXELS := 14.0
## How far under the average the gain starts, in pixels: clear of the resource bar's pill,
## so that drifting up it fades out just under the pill's edge.
const GAIN_DROP := 23.0
## The gain's colours when the average goes up, down, or stays as it shows.
const UP_COLOR := Color(0.55, 0.85, 0.4)
const DOWN_COLOR := Color(0.95, 0.3, 0.4)
const SAME_COLOR := Color(1.0, 1.0, 1.0, 0.6)

## The ratings it shows. Until one is set, or when set to null, it shows a ledger
## of its own, so the scene runs by itself.
var ledger: Ledger:
	set(value):
		if ledger:
			ledger.rated.disconnect(_on_rated)
		ledger = value if value else Ledger.new()
		ledger.rated.connect(_on_rated)
		if _fade:
			_fade.kill()
		_shown_average = ledger.get_recent_rating()
		_shown_count = ledger.get_rating_count()
		if is_node_ready():
			(%GainLabel as Label).modulate.a = 0.0
			_show_average(_shown_average)

# The average and the count the last commit showed.
var _shown_average := 0.0
var _shown_count := 0
# How far the gain has drifted up, in pixels.
var _rise := 0.0
# The commit: the delay, then the move, the fade and the drift, together.
var _fade: Tween
var _pop: Tween


func _ready() -> void:
	if not ledger:
		ledger = Ledger.new()
	(%GainLabel as Label).modulate.a = 0.0
	_show_average(_shown_average)
	_place_gain()


func _process(_delta: float) -> void:
	_place_gain()


# A rating, already in the ledger. The gain shows how far the average has moved since the
# last commit and pops; before the first commit there is nothing to move from, so it stays
# hidden. The average shown waits for [method commit].
func _on_rated(_stars: float) -> void:
	# A commit still under way finishes at once.
	if _fade:
		_fade.kill()
	_show_average(_shown_average)
	if _shown_count == 0:
		return
	var label := %GainLabel as Label
	var change := ledger.get_recent_rating() - _shown_average
	label.text = gain_text(change)
	label.add_theme_color_override(&"font_color", gain_color(change))
	label.modulate.a = 1.0
	_rise = 0.0
	_pop_label(label)


## Moves the average shown to include every rating so far: after [constant COMMIT_DELAY],
## it moves to its new value while the gain fades out drifting upward. The first one pops
## the average instead. Nothing happens without a new rating.
func commit() -> void:
	if ledger.get_rating_count() == _shown_count:
		return
	var from := _shown_average
	var first := _shown_count == 0
	_shown_average = ledger.get_recent_rating()
	_shown_count = ledger.get_rating_count()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_interval(COMMIT_DELAY)
	if first:
		_fade.tween_callback(_show_average.bind(_shown_average))
		_fade.tween_callback(_pop_label.bind(%AverageLabel as Label))
		return
	_fade.tween_method(_show_average, from, _shown_average, COUNT_SECONDS)
	var label := %GainLabel as Label
	_fade.parallel().tween_property(label, ^"modulate:a", 0.0, FADE_OUT_SECONDS)
	(
		_fade
		. parallel()
		. tween_method(
			_set_rise, 0.0, 0.0 if Settings.reduce_motion else RISE_PIXELS, FADE_OUT_SECONDS
		)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUAD)
	)


## The gain for a [param change] to the average, to one decimal, with its sign.
static func gain_text(change: float) -> String:
	var tenths := roundi(change * 10.0)
	if tenths == 0:
		return "±0.0"
	return "%s%.1f" % ["+" if tenths > 0 else "-", absi(tenths) / 10.0]


## The gain's colour for a [param change] to the average, as it shows to one decimal.
static func gain_color(change: float) -> Color:
	var tenths := roundi(change * 10.0)
	if tenths > 0:
		return UP_COLOR
	if tenths < 0:
		return DOWN_COLOR
	return SAME_COLOR


func _show_average(value: float) -> void:
	var label := %AverageLabel as Label
	var text := "%.1f" % value if _shown_count > 0 else NO_RATING
	if label.text != text:
		label.text = text
	var tip := RatingBand.describe(_shown_average)
	if tooltip_text != tip:
		tooltip_text = tip


func _pop_label(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	if _pop:
		_pop.kill()
	if Settings.reduce_motion:
		label.scale = Vector2.ONE
		return
	_pop = create_tween()
	_pop.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		_pop
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _set_rise(value: float) -> void:
	_rise = value
	_place_gain()


# The gain floats centred under the average, GAIN_DROP below it, drifted up by _rise, and
# pops from its centre. It takes no room in the bar.
func _place_gain() -> void:
	var average := %AverageLabel as Label
	var slot := %GainSlot as Control
	slot.position = Vector2(0.0, average.size.y + GAIN_DROP)
	slot.size = Vector2(average.size.x, 0.0)
	var label := %GainLabel as Label
	var size_needed := label.get_combined_minimum_size()
	label.size = size_needed
	label.position = Vector2((slot.size.x - size_needed.x) * 0.5, -_rise)
	label.pivot_offset = size_needed * 0.5
