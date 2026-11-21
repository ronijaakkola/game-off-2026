class_name UpgradeTooltip
extends RefCounted
## What an upgrade's [Tooltip] says, by its state: its name and a short line on what it
## does, and under them, set a little apart, its cost with the resource bar's icons, what the
## player lacks in red. Under the cost, one the player can't afford says so in red. A
## hidden one, or one not open yet, shows "???" and no cost, and a researched one no cost.

## The cost's icons, the resource bar's: a dollar sign in its gold for credits, and a flask
## in the research points' colour for them.
const COST_ICON_SIZE := 12.0
const DOLLAR := preload("res://shared/icons/dollar_sign.svg")
const FLASK := preload("res://shared/icons/flask_conical.svg")
const CREDITS_COLOR := Color(1, 0.831, 0.361)
const LACKING_TEXT := "Insufficient funds"
## Extra room between the description and the cost, over the card's own 4 px between rows.
const COST_GAP := 4
## Between the cost and the line under it.
const NOTE_GAP := 4


## Fills [param tooltip] for [param upgrade] in [param state], with [param credits] and
## [param points] the player has.
static func show(
	tooltip: Tooltip, upgrade: Upgrade, state: Research.State, credits: int, points: int
) -> void:
	var unknown := state == Research.State.HIDDEN or state == Research.State.SHUT
	tooltip.title = "???" if unknown else upgrade.title
	tooltip.sentence = "" if unknown else upgrade.description
	var priced := not unknown and state != Research.State.RESEARCHED
	tooltip.extra = _cost_block(upgrade, state, credits, points) if priced else null


# The cost, set apart from the description, and under it whether the player is short.
static func _cost_block(
	upgrade: Upgrade, state: Research.State, credits: int, points: int
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


static func _cost_row(upgrade: Upgrade, credits: int, points: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	if upgrade.credits > 0:
		row.add_child(_cost(DOLLAR, CREDITS_COLOR, upgrade.credits, credits < upgrade.credits))
	if upgrade.points > 0:
		var lacking := points < upgrade.points
		row.add_child(_cost(FLASK, ResearchCounter.COLOR, upgrade.points, lacking))
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
