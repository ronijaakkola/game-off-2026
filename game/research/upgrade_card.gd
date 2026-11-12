class_name UpgradeCard
extends PanelContainer
## The card the pointer over an upgrade shows, whatever its state: its name, a short line
## on what it does, and its cost, with what the player lacks in red. A hidden upgrade shows
## "???" for its name and description, one in a stage not open yet "???" and that it
## requires a promotion, and a researched one no cost. One the player can research says to
## hold it.

## The cost's icons, the resource bar's: a dollar sign in its gold for credits, and a flask
## in each race's skin colour for its research points.
const COST_ICON_SIZE := 14.0
const DOLLAR := preload("res://game/solar_system/icons/dollar_sign.svg")
const FLASK := preload("res://game/solar_system/icons/flask_conical.svg")
const CREDITS_COLOR := Color(1, 0.831, 0.361)


## Shows [param upgrade] in [param state], with [param credits] and [param points] the
## player has.
func show_upgrade(
	upgrade: Upgrade, state: Research.State, credits: int, points: Dictionary[Race.Type, int]
) -> void:
	var sealed := state == Research.State.NEEDS_PROMOTION
	var hidden_now := state == Research.State.HIDDEN or sealed
	(%TitleLabel as Label).text = "???" if hidden_now else upgrade.title
	var description := "???" if hidden_now else upgrade.description
	if sealed:
		description = "Requires promotion."
	elif state == Research.State.AVAILABLE:
		description += "\nHold to research."
	(%DescriptionLabel as Label).text = description
	var cost := %CostRow as HBoxContainer
	for child: Node in cost.get_children():
		cost.remove_child(child)
		child.queue_free()
	cost.visible = not hidden_now and state != Research.State.RESEARCHED
	if cost.visible:
		_show_cost(upgrade, credits, points)
	reset_size()


func _show_cost(upgrade: Upgrade, credits: int, points: Dictionary[Race.Type, int]) -> void:
	if upgrade.credits > 0:
		_add_cost(DOLLAR, CREDITS_COLOR, upgrade.credits, credits < upgrade.credits)
	for race: Race.Type in upgrade.points:
		var lacking: bool = points.get(race, 0) < upgrade.points[race]
		_add_cost(FLASK, Race.SKIN_COLORS[race], upgrade.points[race], lacking)


func _add_cost(texture: Texture2D, color: Color, amount: int, lacking: bool) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.self_modulate = color
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(COST_ICON_SIZE, COST_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pair := HBoxContainer.new()
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_theme_constant_override(&"separation", 5)
	pair.add_child(icon)
	pair.add_child(_cost_label(str(amount), lacking))
	(%CostRow as HBoxContainer).add_child(pair)


func _cost_label(text: String, lacking: bool) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"PillLabel"
	label.text = text
	label.modulate = UpgradeButton.LACKING_COLOR if lacking else Color.WHITE
	return label
