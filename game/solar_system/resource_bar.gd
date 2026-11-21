class_name ResourceBar
extends PanelContainer
## The resource bar at the top centre: the player's credits, research points and average
## rating in a frosted-glass pill. Each is its own counter, which shows the [member
## ledger]'s value and animates its changes; the bar keeps no values itself. Earnings wait
## to show until [method commit]. When a number gains or loses a digit, the pill's width
## glides to fit, staying centred, while the items stay centred in it; under Reduce motion
## it changes at once. The glass shader draws the pill, and needs the panel's size to find
## its edge, so each bar gets its own copy of the material. [method breathe] makes the
## credits and the research points grow and shrink, slowly and again and again, as
## the tutorial points them out; under Reduce motion they hold still. While
## [member research_hidden], the research points are left out, and [method reveal_research]
## grows them in.

## Seconds the pill takes to reach its new width.
const WIDTH_SECONDS := 0.3
## A breath: how much bigger the numbers grow, and the seconds there and back.
const BREATH_SCALE := 1.15
const BREATH_SECONDS := 1.2
## The research points growing in once the pill has glided open: the seconds it takes and
## how small they start. Under Reduce motion they only fade, in
## [constant REVEAL_FADE_SECONDS].
const REVEAL_SECONDS := 0.35
const REVEAL_FROM := 0.6
const REVEAL_FADE_SECONDS := 0.2

## Whether the research points, and the divider before them, are left out, as until the
## mechanic opens research ([MechanicCall]). The pill is as wide as what it shows.
@export var research_hidden := false:
	set(value):
		research_hidden = value
		if is_node_ready():
			_show_research()

## What the bar shows. Until one is set, its counters each show a ledger of their own, so
## the scene runs by itself.
var ledger: Ledger:
	set(value):
		ledger = value
		if is_node_ready():
			_show_ledger()

# The width the pill is heading to, and the tween taking it there.
var _target_width := 0.0
var _resize: Tween
# The numbers breathing, and the tween that breathes them.
var _breathing: Array[Control] = []
var _breath: Tween
# The research points and their divider fading in, and the points growing.
var _reveal_fade: Tween
var _reveal_grow: Tween
# Holds the research points' place in the row while the pill glides open for them, and
# whether it is.
var _gap: Control
var _revealing := false


func _ready() -> void:
	material = material.duplicate()
	resized.connect(_on_resized)
	var items := %Items as HBoxContainer
	items.minimum_size_changed.connect(_on_items_resized)
	(%Track as Control).resized.connect(_place_items)
	_gap = Control.new()
	_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gap.hide()
	items.add_child(_gap)
	items.move_child(_gap, (%ResearchDivider as Control).get_index())
	_show_research()
	_target_width = items.get_combined_minimum_size().x
	_set_width(_target_width)
	_on_resized()
	if ledger:
		_show_ledger()


## Shows the credits and ratings earned since the last commit: the total counts up and the
## average moves to include them, as their gains and the research points' leave together.
func commit() -> void:
	(%CreditsCounter as CreditsCounter).commit()
	(%ResearchCounter as ResearchCounter).commit()
	(%RatingCounter as RatingCounter).commit()


## Shows the research points, hidden until now: the pill glides open, its neighbours
## parting with its edges, and the points then grow into the room with a slight overshoot
## as they fade in. Under Reduce motion the width changes at once and they only fade.
## Shown already, it does nothing.
func reveal_research() -> void:
	if not research_hidden:
		return
	if Settings.reduce_motion:
		research_hidden = false
		_fade_in_research(REVEAL_FADE_SECONDS)
		return
	var items := %Items as HBoxContainer
	var separation := items.get_theme_constant(&"separation")
	var counter := %ResearchCounter as Control
	var divider := %ResearchDivider as Control
	var from := (%Track as Control).custom_minimum_size.x
	var room := divider.get_combined_minimum_size().x + counter.get_combined_minimum_size().x
	_target_width = from + room + separation * 2.0
	_revealing = true
	_gap.custom_minimum_size.x = 0.0
	_gap.show()
	if _resize:
		_resize.kill()
	_resize = create_tween()
	(
		_resize
		. tween_method(_open_gap.bind(from, separation), from, _target_width, WIDTH_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_resize.tween_callback(_finish_reveal)


## Makes the credits and the research points breathe in size, or, without [param on],
## stops them. While the research points are hidden, only the credits breathe.
func breathe(on: bool) -> void:
	if _breath:
		_breath.kill()
	_set_breath(0.0)
	_breathing.clear()
	if not on or Settings.reduce_motion:
		return
	_breathing.append((%CreditsCounter as CreditsCounter).get_total_label())
	if not research_hidden:
		_breathing.append((%ResearchCounter as ResearchCounter).get_count_label())
	_breath = create_tween().set_loops()
	_breath.tween_method(_set_breath, 0.0, TAU, BREATH_SECONDS)


# Partway through a breath, from 0 to TAU: they swell and settle back, easing both ways.
func _set_breath(phase: float) -> void:
	var grow := (1.0 - cos(phase)) * 0.5 * (BREATH_SCALE - 1.0)
	for label: Control in _breathing:
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2.ONE * (1.0 + grow)


# The pill at [param width], partway open from [param from], and the gap in the row as
# wide as the room it has made, so the credits and the rating part with its edges.
func _open_gap(width: float, from: float, separation: float) -> void:
	_set_width(width)
	_gap.custom_minimum_size.x = maxf(width - from - separation, 0.0)


# The pill is open: the points take the gap's place and grow in.
func _finish_reveal() -> void:
	_gap.hide()
	_revealing = false
	research_hidden = false
	_fade_in_research(REVEAL_SECONDS * 0.5)
	var counter := %ResearchCounter as Control
	counter.pivot_offset = counter.get_combined_minimum_size() * 0.5
	counter.scale = Vector2.ONE * REVEAL_FROM
	if _reveal_grow:
		_reveal_grow.kill()
	_reveal_grow = create_tween()
	(
		_reveal_grow
		. tween_property(counter, ^"scale", Vector2.ONE, REVEAL_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


# The research points and their divider fade in over [param seconds].
func _fade_in_research(seconds: float) -> void:
	var counter := %ResearchCounter as Control
	var divider := %ResearchDivider as Control
	counter.modulate.a = 0.0
	divider.modulate.a = 0.0
	if _reveal_fade:
		_reveal_fade.kill()
	_reveal_fade = create_tween().set_parallel()
	_reveal_fade.tween_property(counter, ^"modulate:a", 1.0, seconds)
	_reveal_fade.tween_property(divider, ^"modulate:a", 1.0, seconds)


## The research points, for a guide card to point at.
func get_research_counter() -> Control:
	return %ResearchCounter as Control


func _show_research() -> void:
	(%ResearchCounter as Control).visible = not research_hidden
	(%ResearchDivider as Control).visible = not research_hidden


func _show_ledger() -> void:
	(%CreditsCounter as CreditsCounter).ledger = ledger
	(%ResearchCounter as ResearchCounter).ledger = ledger
	(%RatingCounter as RatingCounter).ledger = ledger


func _on_items_resized() -> void:
	_place_items()
	# The reveal glides the pill itself.
	if _revealing:
		return
	var width := (%Items as HBoxContainer).get_combined_minimum_size().x
	if is_equal_approx(width, _target_width):
		return
	_target_width = width
	if _resize:
		_resize.kill()
	if Settings.reduce_motion:
		_set_width(width)
		return
	var from := (%Track as Control).custom_minimum_size.x
	_resize = create_tween()
	(
		_resize
		. tween_method(_set_width, from, width, WIDTH_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func _set_width(width: float) -> void:
	var height := (%Items as HBoxContainer).get_combined_minimum_size().y
	(%Track as Control).custom_minimum_size = Vector2(width, height)


# The items keep their own size and sit in the middle of the track, so while the pill
# grows, they reach a little into its padding on both sides until it catches up.
func _place_items() -> void:
	var items := %Items as HBoxContainer
	var track := %Track as Control
	items.size = items.get_combined_minimum_size()
	items.position = (track.size - items.size) * 0.5


func _on_resized() -> void:
	(material as ShaderMaterial).set_shader_parameter(&"size", size)
