extends CanvasLayer
## The solar system's HUD layer. While a side panel is open, it hides the bus bars and the
## notices above them, which sit under the panel, fades the goal panel out, which the panel
## would slice, and keeps the resource bar centred in the gap
## between the On board panel and the side panel, so the bar glides aside as the side
## panel slides in and back as it slides out. The notices sit on top of the bus bars, so
## they rise and fall with the route bar as it opens and closes.

## Seconds the goal panel takes to fade out and back, also under Reduce motion.
const GOAL_FADE_SECONDS := 0.2

# The resource bar's margins, left and right, as last set.
var _margins := Vector2i.ZERO
# Whether the goal panel is faded out for an open side panel, and the tween that fades it.
var _goals_hidden := false
var _goal_fade: Tween


func _process(_delta: float) -> void:
	var side := (%BusPanel if (%BusPanel as Control).visible else %PlanetPanel) as Control
	(%Notices as Control).visible = not side.visible
	(%BusStatusPanel as Control).visible = not side.visible
	# By the bars' height this frame, not the panel's offsets, which it sets after this
	# runs: the route bar has already eased its height (it runs first).
	var notices := %Notices as Control
	notices.offset_bottom = -(%BusStatusPanel as Control).get_combined_minimum_size().y
	notices.offset_top = notices.offset_bottom
	if side.visible != _goals_hidden:
		_goals_hidden = side.visible
		_fade_goals()
	var covered := get_viewport().get_visible_rect().end.x - side.global_position.x
	var margins := Vector2i.ZERO
	if side.visible and covered > 0.0:
		var left := (%PassengerPanel as Control).get_global_rect().end.x
		margins = Vector2i(roundi(left), roundi(covered))
	if margins != _margins:
		_margins = margins
		var top := %TopCentre as Control
		top.add_theme_constant_override(&"margin_left", margins.x)
		top.add_theme_constant_override(&"margin_right", margins.y)


func _fade_goals() -> void:
	var goals := %GoalPanel as Control
	if _goal_fade:
		_goal_fade.kill()
	_goal_fade = create_tween()
	_goal_fade.tween_property(
		goals, ^"modulate:a", 0.0 if _goals_hidden else 1.0, GOAL_FADE_SECONDS
	)
