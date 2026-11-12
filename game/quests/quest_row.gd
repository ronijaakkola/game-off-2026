class_name QuestRow
extends VBoxContainer
## One quest in the goal panel. On top, an icon, what it asks and the planet it is about.
## Under it, the passenger who asked, as a small portrait and their name, and
## the reward at the right: the credits by a gold dollar sign, and each race's research
## points by a flask in its colour.
## The icon is an empty circle while the quest is under way, a green tick once it is done,
## and a red cross when it failed. A failed quest's top line dims, the reward goes, and
## why it failed takes the name's place.

const DONE_COLOR := Color(0.549, 0.851, 0.4)
const FAILED_COLOR := Color(0.949, 0.302, 0.4)
const UNDER_WAY_COLOR := Color(0.957, 0.945, 1.0, 0.651)
const CREDITS_COLOR := Color(1.0, 0.831, 0.361)
## How faint a failed quest's top line is.
const FAILED_OPACITY := 0.5
const CIRCLE := preload("res://game/goals/icons/circle.svg")
const CIRCLE_CHECK := preload("res://game/goals/icons/circle_check.svg")
const CIRCLE_X := preload("res://game/goals/icons/circle_x.svg")
const DOLLAR := preload("res://game/solar_system/icons/dollar_sign.svg")
const FLASK := preload("res://game/solar_system/icons/flask_conical.svg")
## A reward icon's size, in pixels.
const REWARD_ICON := 12.0

## Where the passenger's portrait is rendered.
var studio: PortraitStudio:
	set(value):
		studio = value
		if is_node_ready():
			(%Photo as PassengerPhoto).studio = studio
## The quest shown.
var quest: Quest:
	set(value):
		if quest and quest.goal:
			quest.goal.changed.disconnect(refresh)
		quest = value
		if quest and quest.goal:
			quest.goal.changed.connect(refresh)
		if is_node_ready():
			_fill()


func _ready() -> void:
	(%Photo as PassengerPhoto).studio = studio
	_fill()


## Shows the quest as it stands now.
func refresh() -> void:
	if not quest or not quest.goal:
		return
	var goal := quest.goal
	var failed := goal.state == Goal.State.FAILED
	var icon := %Icon as TextureRect
	icon.texture = CIRCLE
	icon.self_modulate = UNDER_WAY_COLOR
	if failed:
		icon.texture = CIRCLE_X
		icon.self_modulate = FAILED_COLOR
	elif goal.is_met():
		icon.texture = CIRCLE_CHECK
		icon.self_modulate = DONE_COLOR
	(%Ask as Control).modulate.a = FAILED_OPACITY if failed else 1.0
	var who := quest.passenger.name if quest.passenger else ""
	(%NameLabel as Label).text = goal.failure if failed and goal.failure else who
	(%Reward as Control).visible = not failed


# What never changes while the quest shows: what it asks, who asked and the reward.
func _fill() -> void:
	if not quest:
		return
	(%AskLabel as Label).text = quest.get_ask()
	var planet := quest.get_planet()
	(%PlanetIcon as PlanetIcon).planet = planet
	(%PlanetLabel as Label).visible = planet != null
	if planet:
		var named := planet.display_name if planet.display_name else String(planet.name)
		(%PlanetLabel as Label).text = named
	(%Photo as PassengerPhoto).passenger = quest.passenger
	var reward := %Reward as Control
	for part: Node in reward.get_children():
		reward.remove_child(part)
		part.queue_free()
	if quest.reward_credits > 0:
		reward.add_child(_reward_part(DOLLAR, CREDITS_COLOR, quest.reward_credits))
	for race: Race.Type in quest.reward_research:
		var points := quest.reward_research[race]
		reward.add_child(_reward_part(FLASK, Race.SKIN_COLORS[race], points))
	refresh()


# An icon in [param color] and [param amount] beside it.
func _reward_part(texture: Texture2D, color: Color, amount: int) -> Control:
	var part := HBoxContainer.new()
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.add_theme_constant_override(&"separation", 3)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * REWARD_ICON
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.self_modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = &"SmallStrongLabel"
	label.text = str(amount)
	part.add_child(label)
	return part
