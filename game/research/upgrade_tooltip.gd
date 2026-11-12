class_name UpgradeTooltip
extends RefCounted
## What an upgrade's [Tooltip] says, by its state: its name and a short line on what it
## does, and under them, set a little apart, its cost with the resource bar's icons, what the
## player lacks in red. Under the cost, one the player can't afford says so in red. A
## hidden one shows "???" and no cost, one in a stage not open yet "???" and that it
## requires a promotion, and a researched one no cost.

## The cost's icons, the resource bar's: a dollar sign in its gold for credits, and a flask
## in each race's skin colour for its research points.
const COST_ICON_SIZE := 12.0
const DOLLAR := preload("res://game/solar_system/icons/dollar_sign.svg")
const FLASK := preload("res://game/solar_system/icons/flask_conical.svg")
const CREDITS_COLOR := Color(1, 0.831, 0.361)
const LACKING_TEXT := "Insufficient funds"
const PROMOTION_TEXT := "Requires promotion."
## Extra room between the description and the cost, over the card's own 4 px between rows.
const COST_GAP := 4
## Between the cost and the line under it.
const NOTE_GAP := 4


## Fills [param tooltip] for [param upgrade] in [param state], with [param credits] and
## [param points] the player has.
static func show(
	tooltip: Tooltip,
	upgrade: Upgrade,
	state: Research.State,
	credits: int,
	points: Dictionary[Race.Type, int]
) -> void:
	var sealed := state == Research.State.NEEDS_PROMOTION
	var unknown := state == Research.State.HIDDEN or sealed
	tooltip.title = "???" if unknown else upgrade.title
	var sentence := "" if unknown else upgrade.description
	if sealed:
		sentence = PROMOTION_TEXT
	tooltip.sentence = sentence
	var priced := not unknown and state != Research.State.RESEARCHED
	tooltip.extra = _cost_block(upgrade, state, credits, points) if priced else null


# The cost, set apart from the description, and under it whether the player is short.
static func _cost_block(
	upgrade: Upgrade, state: Research.State, credits: int, points: Dictionary[Race.Type, int]
) -> Control:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()
	gap.custom_minimum_size.y = COST_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override(&"separation", 0)
	block.add_child(gap)
	block.add_child(_cost_row(upgrade, credits, points))
	if state == Research.State.UNAFFORDABLE:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = NOTE_GAP
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(spacer)
		var label := Label.new()
		label.theme_type_variation = &"TooltipSentenceLabel"
		label.text = LACKING_TEXT
		label.add_theme_color_override(&"font_color", UpgradeButton.LACKING_COLOR)
		block.add_child(label)
	return block


static func _cost_row(
	upgrade: Upgrade, credits: int, points: Dictionary[Race.Type, int]
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	if upgrade.credits > 0:
		row.add_child(_cost(DOLLAR, CREDITS_COLOR, upgrade.credits, credits < upgrade.credits))
	for race: Race.Type in upgrade.points:
		var lacking: bool = points.get(race, 0) < upgrade.points[race]
		row.add_child(_cost(FLASK, Race.SKIN_COLORS[race], upgrade.points[race], lacking))
	return row


static func _cost(texture: Texture2D, color: Color, amount: int, lacking: bool) -> Control:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.self_modulate = color
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * COST_ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"SmallStrongLabel"
	label.text = str(amount)
	label.modulate = UpgradeButton.LACKING_COLOR if lacking else Color.WHITE
	var pair := HBoxContainer.new()
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_theme_constant_override(&"separation", 4)
	pair.add_child(icon)
	pair.add_child(label)
	return pair
