class_name ResourceBar
extends PanelContainer
## The resource bar at the top centre: the player's credits, research points and average
## rating in a frosted-glass pill. Each is its own counter, which shows the [member
## ledger]'s value and animates its changes; the bar keeps no values itself. Earnings wait
## to show until [method commit]. When a number gains or loses a digit, the pill's width
## glides to fit, staying centred, while the items stay centred in it; under Reduce motion
## it changes at once. The glass shader draws the pill, and needs the panel's size to find
## its edge, so each bar gets its own copy of the material.

## Seconds the pill takes to reach its new width.
const WIDTH_SECONDS := 0.3
## The height of the row the items sit centred in, so the pill is as tall as the On board
## panel's header row (8 px padding above and below), and their text shares its centre line.
const ROW_HEIGHT := 24.0

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


func _ready() -> void:
	material = material.duplicate()
	resized.connect(_on_resized)
	var items := %Items as HBoxContainer
	items.minimum_size_changed.connect(_on_items_resized)
	(%Track as Control).resized.connect(_place_items)
	_target_width = items.get_combined_minimum_size().x
	_set_width(_target_width)
	_on_resized()
	if ledger:
		_show_ledger()


## Shows the credits and ratings earned since the last commit: the total counts up and the
## average moves to include them.
func commit() -> void:
	(%CreditsCounter as CreditsCounter).commit()
	(%RatingCounter as RatingCounter).commit()


func _show_ledger() -> void:
	(%CreditsCounter as CreditsCounter).ledger = ledger
	(%ResearchCounter as ResearchCounter).ledger = ledger
	(%RatingCounter as RatingCounter).ledger = ledger


func _on_items_resized() -> void:
	_place_items()
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
	var height := maxf((%Items as HBoxContainer).get_combined_minimum_size().y, ROW_HEIGHT)
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
