class_name ResourceBar
extends PanelContainer
## The resource bar in the top right corner: the player's credits, research points and
## average rating in a frosted-glass pill. Each is its own counter, which keeps the value
## and animates its changes; the solar system reaches them through the getters.
## When a number gains or loses a digit, the pill's width glides to fit, its right edge
## staying put, while the items stay pinned to that edge; under Reduce motion it changes
## at once. The glass shader draws the pill, and needs the panel's size to find its edge,
## so each bar gets its own copy of the material.

## Seconds the pill takes to reach its new width.
const WIDTH_SECONDS := 0.3

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


func get_credits() -> CreditsCounter:
	return %CreditsCounter as CreditsCounter


func get_research() -> ResearchCounter:
	return %ResearchCounter as ResearchCounter


func get_rating() -> RatingCounter:
	return %RatingCounter as RatingCounter


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
	var height := (%Items as HBoxContainer).get_combined_minimum_size().y
	(%Track as Control).custom_minimum_size = Vector2(width, height)


# The items keep their own width and sit against the track's right edge, so while the pill
# grows, they reach a little into its padding on the left until it catches up.
func _place_items() -> void:
	var items := %Items as HBoxContainer
	var track := %Track as Control
	items.size = items.get_combined_minimum_size()
	items.position = Vector2(track.size.x - items.size.x, 0.0)


func _on_resized() -> void:
	(material as ShaderMaterial).set_shader_parameter(&"size", size)
