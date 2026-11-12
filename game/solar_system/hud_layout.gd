extends CanvasLayer
## The solar system's HUD layer. While a side panel is open, it hides the bus bars and the
## notices above them, which sit under the panel, and keeps the resource bar centred in the gap
## between the On board panel and the side panel, so the bar glides aside as the side
## panel slides in and back as it slides out.

# The resource bar's margins, left and right, as last set.
var _margins := Vector2i.ZERO


func _process(_delta: float) -> void:
	var side := (%BusPanel if (%BusPanel as Control).visible else %PlanetPanel) as Control
	(%Notices as Control).visible = not side.visible
	(%BusStatusPanel as Control).visible = not side.visible
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
