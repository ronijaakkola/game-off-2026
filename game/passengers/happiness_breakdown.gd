class_name HappinessBreakdown
extends Control
## The part of a passenger's happiness bar the pointer rests on to ask why it stands where
## it does: it covers the bar and a little above and below, and opens a panel to the
## right, its notch pointing at the bar, with a face in their mood's colour and the mood's
## name, and under it what is moving their happiness, one line each with an arrow, up in
## the gain's green or down in the loss's red ([HappinessCause]). No numbers. The card
## tells it who to show every frame ([method follow]). Put it first among the bar's
## children, so the striped end and the docked mark, which have tooltips of their own, sit
## over it.

const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const ARROW_UP := preload("res://game/passengers/icons/arrow_up.svg")
const ARROW_DOWN := preload("res://game/passengers/icons/arrow_down.svg")
const FACES: Dictionary[Passenger.Mood, Texture2D] = {
	Passenger.Mood.HAPPY: preload("res://game/passengers/icons/smile.svg"),
	Passenger.Mood.OKAY: preload("res://game/passengers/icons/meh.svg"),
	Passenger.Mood.ANNOYED: preload("res://game/passengers/icons/frown.svg"),
	Passenger.Mood.FURIOUS: preload("res://game/passengers/icons/angry.svg"),
}
const MOOD_NAMES: Dictionary[Passenger.Mood, String] = {
	Passenger.Mood.HAPPY: "Happy",
	Passenger.Mood.OKAY: "Okay",
	Passenger.Mood.ANNOYED: "Annoyed",
	Passenger.Mood.FURIOUS: "Furious",
}
const UP_COLOR := Color(0.549, 0.851, 0.4)
const DOWN_COLOR := Color(0.949, 0.302, 0.4)
const LABEL_COLOR := Color(0.957, 0.945, 1.0, 0.651)
## The face's and an arrow's size, and the gap between the face and the mood's name, in
## pixels. The lines' words start under the name.
const FACE_SIZE := 18.0
const ARROW_SIZE := 12.0
const GAP := 6
## How far past the bar's top and bottom it takes the pointer, in pixels: the bar alone is
## too thin to rest on.
const HOVER_MARGIN := 3.0

var _tooltip: Tooltip
# What the panel last showed, so it is rebuilt only when that changes.
var _shown := ""


func _ready() -> void:
	# It takes the pointer for its panel and passes it on, so the card still sees it.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tooltip = TOOLTIP.instantiate() as Tooltip
	_tooltip.target = self
	_tooltip.side = Tooltip.Side.RIGHT
	_tooltip.notch = true
	add_child(_tooltip)
	_tooltip.theme_type_variation = &"TooltipCardPanel"


## Covers [param bar], the [ProgressBar] it is a child of, and shows [param passenger] on
## a bus giving [param comfort], [param docked] or not, in [param mood_colors], the card's.
func follow(
	passenger: Passenger,
	comfort: Comfort,
	docked: bool,
	bar: ProgressBar,
	mood_colors: Dictionary[Passenger.Mood, Color]
) -> void:
	position = Vector2(0.0, -HOVER_MARGIN)
	size = bar.size + Vector2(0.0, HOVER_MARGIN * 2.0)
	var mood := passenger.get_mood()
	var ups := HappinessCause.get_ups(passenger, comfort)
	var downs := HappinessCause.get_downs(passenger, comfort, docked)
	var showing := "%d|%s|%s" % [mood, "/".join(ups), "/".join(downs)]
	if showing == _shown:
		return
	_shown = showing
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 4)
	rows.add_child(_row(FACES[mood], FACE_SIZE, MOOD_NAMES[mood], mood_colors[mood], true))
	for up: String in ups:
		rows.add_child(_row(ARROW_UP, ARROW_SIZE, up, UP_COLOR, false))
	for down: String in downs:
		rows.add_child(_row(ARROW_DOWN, ARROW_SIZE, down, DOWN_COLOR, false))
	_tooltip.extra = rows


# One line: [param icon] at [param icon_size] in [param color], then [param text], which
# takes the colour too when [param strong], as the mood's name does.
func _row(
	icon: Texture2D, icon_size: float, text: String, color: Color, strong: bool
) -> HBoxContainer:
	var row := HBoxContainer.new()
	# A smaller icon keeps its left edge, and its words still start where the name does.
	row.add_theme_constant_override(&"separation", GAP + roundi(FACE_SIZE - icon_size))
	var picture := TextureRect.new()
	picture.texture = icon
	picture.modulate = color
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.custom_minimum_size = Vector2.ONE * icon_size
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"StrongLabel" if strong else &"BodyTextLabel"
	label.add_theme_color_override(&"font_color", color if strong else LABEL_COLOR)
	row.add_child(picture)
	row.add_child(label)
	return row
