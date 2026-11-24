@tool
class_name SlantColumn
extends Container
## Stacks its children top to bottom and moves each left by how far down it sits, so the
## left edges of their slanted plates (the SlantButton theme types) make one line, leaning
## as the plates do. The line runs through the column's top left corner, so a row showing
## or hiding below leaves the rows above where they are; the rows below the top reach left
## of the column. Hidden children take no room.

## The gap between rows.
@export var separation := 16:
	set(value):
		separation = value
		queue_sort()
## How far the line moves left for each pixel down: the plates' lean, their
## [member StyleBoxFlat.skew] x.
@export var lean := 0.176:
	set(value):
		lean = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var y := 0.0
		for child: Control in _rows():
			var height := child.get_combined_minimum_size().y
			# A plate is skewed round its middle, so its rect sits half its own lean right of
			# the line's x at its bottom.
			var x := -lean * (y + height / 2.0)
			fit_child_in_rect(child, Rect2(x, y, child.get_combined_minimum_size().x, height))
			y += height + separation


func _get_minimum_size() -> Vector2:
	var minimum := Vector2.ZERO
	for child: Control in _rows():
		var child_size := child.get_combined_minimum_size()
		minimum.x = maxf(minimum.x, child_size.x)
		minimum.y += child_size.y + separation
	if minimum.y > 0.0:
		minimum.y -= separation
	return minimum


func _rows() -> Array[Control]:
	var rows: Array[Control] = []
	for child: Node in get_children():
		var control := child as Control
		if control and control.visible and not control.top_level:
			rows.append(control)
	return rows
