class_name GoalRow
extends VBoxContainer
## One goal in the goal panel: an icon, what to do and how far along it is, over a thin
## bar. The icon is an empty circle until the goal is met, then a green tick, and the bar
## turns green with it. A delivery goal shows its count ("12/50") and fills with it. A
## rating goal shows the recent rating ("4.2", or a dash before the first rating) on a bar of
## five stars, with a mark at the target. Any other goal shows only its text and icon.
## A failed goal's icon is a red cross.

const MET_COLOR := Color(0.549, 0.851, 0.4)
const FAILED_COLOR := Color(0.949, 0.302, 0.4)
const UNMET_ICON_COLOR := Color(0.957, 0.945, 1.0, 0.651)
const CIRCLE := preload("res://game/goals/icons/circle.svg")
const CIRCLE_CHECK := preload("res://shared/icons/circle_check.svg")
const CIRCLE_X := preload("res://game/goals/icons/circle_x.svg")
const NO_RATING := "–"
# The target mark on a rating goal's bar, in pixels wide.
const MARKER_WIDTH := 2.0

## The goal shown. The parent calls [method refresh] when it changes.
var goal: Goal:
	set(value):
		goal = value
		if is_node_ready():
			refresh()

var _met_fill: StyleBox


func _ready() -> void:
	var fill := (%Bar as ProgressBar).get_theme_stylebox(&"fill").duplicate() as StyleBoxFlat
	fill.bg_color = MET_COLOR
	_met_fill = fill
	refresh()


## Shows the goal as it stands now.
func refresh() -> void:
	if not goal:
		return
	var met := goal.is_met()
	var failed := goal.state == Goal.State.FAILED
	var icon := %Icon as TextureRect
	icon.texture = CIRCLE_CHECK if met else CIRCLE
	icon.self_modulate = MET_COLOR if met else UNMET_ICON_COLOR
	if failed:
		icon.texture = CIRCLE_X
		icon.self_modulate = FAILED_COLOR
	(%TextLabel as Label).text = goal.get_text()
	var bar := %Bar as ProgressBar
	if met:
		bar.add_theme_stylebox_override(&"fill", _met_fill)
	else:
		bar.remove_theme_stylebox_override(&"fill")
	var value := %ValueLabel as Label
	var marker := %Marker as Control
	marker.visible = false
	bar.visible = true
	if goal is DeliveryCountGoal:
		var count := goal as DeliveryCountGoal
		value.text = "%d/%d" % [mini(count.delivered, count.target), count.target]
		bar.value = goal.get_progress()
	elif goal is RatingGoal:
		var rating := goal as RatingGoal
		value.text = "%.1f" % rating.rating if rating.rides > 0 else NO_RATING
		bar.value = rating.rating / Passenger.MAX_STARS
		var share := rating.target / Passenger.MAX_STARS
		marker.set_anchor_and_offset(SIDE_LEFT, share, -MARKER_WIDTH / 2.0)
		marker.set_anchor_and_offset(SIDE_RIGHT, share, MARKER_WIDTH / 2.0)
		marker.visible = true
	else:
		value.text = ""
		bar.visible = false
	value.visible = not value.text.is_empty()
