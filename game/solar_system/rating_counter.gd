class_name RatingCounter
extends HBoxContainer
## The player's recent rating in the resource bar: a star and the mean of the last ratings
## passengers gave on getting off ([method Ledger.get_recent_rating]), to one decimal, or a
## dash before the first, in the room a rating takes so the bar keeps its width. Like the
## credits, ratings collect first: the change they make to the average shows in a gain, a
## [ChangeChip] under the bar ("+0.2" in green, "-0.3" in red). Once [method commit] is
## called, after a short delay the gain slides back under the bar while the average moves
## to its new value in the gain's colour. It shows the ratings of its [member ledger] and
## animates each one the ledger signals; it keeps no ratings of its own. The ledger already
## counts every rating; only what shows waits.

## What shows before anyone has rated a ride.
const NO_RATING := "–"
## Seconds from [method commit] to the average starting to move, and how long it takes.
const COMMIT_DELAY := ChangeChip.HOLD_SECONDS
const COUNT_SECONDS := 0.5
## Seconds the average takes to turn white again once it has moved.
const TINT_OUT_SECONDS := 0.2
## How much bigger the first average pops, and the seconds up and back down.
const POP_SCALE := 1.35
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14
## The gain's colours when the average goes up, down, or stays as it shows.
const UP_COLOR := ChangeChip.GAIN_COLOR
const DOWN_COLOR := ChangeChip.LOSS_COLOR
const SAME_COLOR := Color(1.0, 1.0, 1.0, 0.6)

## The ratings it shows. Until one is set, or when set to null, it shows a ledger
## of its own, so the scene runs by itself.
var ledger: Ledger:
	set(value):
		if ledger:
			ledger.rated.disconnect(_on_rated)
		ledger = value if value else Ledger.new()
		ledger.rated.connect(_on_rated)
		_end_move()
		_shown_average = ledger.get_recent_rating()
		_shown_count = ledger.get_rating_count()
		if is_node_ready():
			(%GainChip as ChangeChip).hide_now()
			_show_average(_shown_average)

# The average and the count the last commit showed.
var _shown_average := 0.0
var _shown_count := 0
# The commit: the delay, then the gain leaving as the average moves.
var _fade: Tween
var _pop: Tween


func _ready() -> void:
	if not ledger:
		ledger = Ledger.new()
	(%GainChip as ChangeChip).target = %AverageLabel
	(%GainChip as ChangeChip).row = self
	_show_average(_shown_average)


# A rating, already in the ledger. The gain shows how far the average has moved since the
# last commit; before the first commit there is nothing to move from, so it stays
# hidden. The average shown waits for [method commit].
func _on_rated(_stars: float) -> void:
	# A commit still under way finishes at once.
	_end_move()
	_show_average(_shown_average)
	if _shown_count == 0:
		return
	var change := ledger.get_recent_rating() - _shown_average
	(%GainChip as ChangeChip).show_change(gain_text(change), gain_color(change))


## Moves the average shown to include every rating so far: after [constant COMMIT_DELAY],
## the gain slides back under the bar while it moves to its new value. The first one pops
## the average instead. Nothing happens without a new rating.
func commit() -> void:
	if ledger.get_rating_count() == _shown_count:
		return
	var from := _shown_average
	var first := _shown_count == 0
	_shown_average = ledger.get_recent_rating()
	_shown_count = ledger.get_rating_count()
	_end_move()
	_fade = create_tween()
	_fade.tween_interval(COMMIT_DELAY)
	if first:
		_fade.tween_callback(_show_average.bind(_shown_average))
		_fade.tween_callback(_pop_label.bind(%AverageLabel as Label))
		return
	_fade.tween_callback((%GainChip as ChangeChip).leave)
	_fade.tween_callback(_tint.bind(gain_color(_shown_average - from)))
	_fade.tween_method(_show_average, from, _shown_average, COUNT_SECONDS)
	_fade.tween_property(%AverageLabel, ^"self_modulate", Color.WHITE, TINT_OUT_SECONDS)


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


# Turns the average [param color] while it moves. A change too small to show leaves it
# white.
func _tint(color: Color) -> void:
	if color != SAME_COLOR:
		(%AverageLabel as Label).self_modulate = color


# Ends a commit under way at once, the average white again. What it shows is for whoever
# ends it to set.
func _end_move() -> void:
	if _fade:
		_fade.kill()
	if is_node_ready():
		(%AverageLabel as Label).self_modulate = Color.WHITE
