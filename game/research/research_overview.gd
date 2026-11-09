class_name ResearchOverview
extends PanelContainer
## The debug panel's View research tree: a modal over almost the whole screen with every
## planet's research tree side by side, each under its planet's name. Upgrades show their
## states as in the planet panel, but the bus needn't be docked anywhere: a click on an
## available upgrade only asks, and the parent researches it. The close button, the pause
## action (Esc) and a click outside the sheet close it.

## The player clicked [param upgrade], which is available.
signal upgrade_clicked(upgrade: Upgrade)

## Pixels between two upgrades in a row, tighter than the planet panel's so three trees fit
## the smallest window side by side.
const COLUMN_GAP := 14
## The line between two trees, as faint as the planet panel's rules.
const DIVIDER_COLOR := Color(1, 1, 1, 0.1)
const DIVIDER_WIDTH := 1.0

const TREE_VIEW := preload("res://game/research/research_tree_view.tscn")

var _views: Array[ResearchTreeView] = []


func _ready() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


## Shows the trees of [param planets] side by side with a line between each two, leaving
## out any planet without one.
func open(planets: Array[Planet]) -> void:
	var trees := %Trees as HBoxContainer
	for child: Node in trees.get_children():
		trees.remove_child(child)
		child.queue_free()
	_views.clear()
	for planet: Planet in planets:
		if not planet.research_tree:
			continue
		if not _views.is_empty():
			trees.add_child(_make_divider())
		trees.add_child(_make_column(planet))
	show()


## Hides it.
func close() -> void:
	hide()


## Whether it shows.
func is_open() -> bool:
	return visible


## Shows each upgrade's state from [param research], with [param credits] and
## [param points] the player has. Only what changed is redrawn, so the parent can call it
## every frame.
func show_research(research: Research, credits: int, points: Dictionary[Race.Type, int]) -> void:
	for view: ResearchTreeView in _views:
		view.show_state(research, credits, points, true)


# A column with the planet's name over its tree.
func _make_column(planet: Planet) -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 12)
	var title := Label.new()
	title.text = planet.display_name if planet.display_name else String(planet.name)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var view := TREE_VIEW.instantiate() as ResearchTreeView
	view.column_gap = COLUMN_GAP
	view.tree = planet.research_tree
	view.upgrade_clicked.connect(upgrade_clicked.emit)
	column.add_child(view)
	_views.append(view)
	return column


# A faint line between two trees, as tall as they are.
func _make_divider() -> Control:
	var divider := ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = DIVIDER_COLOR
	divider.custom_minimum_size.x = DIVIDER_WIDTH
	return divider


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()


func _on_close_button_pressed() -> void:
	close()
