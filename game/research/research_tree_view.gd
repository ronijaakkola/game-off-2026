class_name ResearchTreeView
extends VBoxContainer
## A planet's research tree drawn top to bottom: a row for each tier, each upgrade in its
## column, and a line from each upgrade up to each one it requires, in that one's race's
## colour once it is researched. The pointer over an upgrade shows its card under it,
## whatever its state. While the bus isn't docked at the planet, the whole tree is dimmed
## and a note says so.
## A click on an available upgrade only asks; the parent researches it.

## The player clicked [param upgrade], which is available, while the bus is docked here.
signal upgrade_clicked(upgrade: Upgrade)

## Pixels between two upgrades in a row, unless [member column_gap] says otherwise.
const COLUMN_GAP := 28
## Pixels between two tiers, where the lines run, unless [member tier_gap] says otherwise.
const TIER_GAP := 20
## Pixels between an upgrade and its card.
const CARD_GAP := 6.0
const LINE_WIDTH := 2.0
const LINE_COLOR := Color(1, 1, 1, 0.18)
## How much the tree dims while the bus isn't docked here.
const DIMMED := 0.5

## The tree it draws, or null for none.
var tree: ResearchTree:
	set(value):
		tree = value
		if is_node_ready():
			_build()

## Pixels between two upgrades in a row. Set it before the view enters the tree.
var column_gap := COLUMN_GAP
## Pixels between two tiers, where the lines run. Set it before the view enters the tree.
var tier_gap := TIER_GAP
## The side of each upgrade's tile, in pixels ([member UpgradeButton.tile_size]). Set it
## before the view enters the tree.
var tile_size := UpgradeButton.SIZE.x

var _buttons: Array[UpgradeButton] = []
var _hovered: UpgradeButton
var _research: Research
var _credits := 0
var _points: Dictionary[Race.Type, int] = {}
var _can_research := false


func _ready() -> void:
	(%Tiers as VBoxContainer).add_theme_constant_override(&"separation", tier_gap)
	(%Tiers as Control).sort_children.connect(queue_redraw)
	(%Card as Control).hide()
	visibility_changed.connect(_on_visibility_changed)
	_build()


## Shows each upgrade's state from [param research], with [param credits] and
## [param points] the player has, and [param can_research] whether the bus is docked here.
## Only what changed is redrawn, so the parent can call it every frame.
func show_state(
	research: Research, credits: int, points: Dictionary[Race.Type, int], can_research: bool
) -> void:
	var changed := (
		research != _research
		or credits != _credits
		or points != _points
		or can_research != _can_research
	)
	if research != _research:
		if _research:
			_research.researched.disconnect(_on_researched)
		research.researched.connect(_on_researched)
	_research = research
	_credits = credits
	_points = points
	_can_research = can_research
	if changed:
		_refresh()


func _build() -> void:
	var tiers := %Tiers as VBoxContainer
	for child: Node in tiers.get_children():
		tiers.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_hovered = null
	(%Card as Control).hide()
	if not tree:
		return
	var tier_count := 0
	var column_count := 0
	for upgrade: Upgrade in tree.upgrades:
		tier_count = maxi(tier_count, upgrade.tier + 1)
		column_count = maxi(column_count, upgrade.column + 1)
	for tier: int in tier_count:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", column_gap)
		tiers.add_child(row)
		for column: int in column_count:
			var upgrade := _upgrade_at(tier, column)
			if not upgrade:
				var gap := Control.new()
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				gap.custom_minimum_size = Vector2(tile_size, tile_size)
				row.add_child(gap)
				continue
			var button := UpgradeButton.new()
			button.upgrade = upgrade
			button.tile_size = tile_size
			button.hovered.connect(_on_button_hovered.bind(button))
			button.unhovered.connect(_on_button_unhovered.bind(button))
			button.clicked.connect(_on_button_clicked.bind(button))
			row.add_child(button)
			_buttons.append(button)
	_refresh()


func _upgrade_at(tier: int, column: int) -> Upgrade:
	for upgrade: Upgrade in tree.upgrades:
		if upgrade.tier == tier and upgrade.column == column:
			return upgrade
	return null


func _refresh() -> void:
	(%NoteLabel as Control).visible = tree != null and not _can_research
	(%Tiers as Control).modulate.a = 1.0 if _can_research else DIMMED
	if not _research:
		return
	for button: UpgradeButton in _buttons:
		var state := _research.get_state(button.upgrade, _credits, _points)
		button.show_state(state)
	if _hovered:
		_show_card(_hovered)
	queue_redraw()


func _draw() -> void:
	var dim := 1.0 if _can_research else DIMMED
	for button: UpgradeButton in _buttons:
		var rect := _local_rect(button)
		var to := Vector2(rect.get_center().x, rect.position.y)
		for required: Upgrade in button.upgrade.requires:
			var from_button := _button_for(required)
			if not from_button:
				continue
			var from_rect := _local_rect(from_button)
			var from := Vector2(from_rect.get_center().x, from_rect.end.y)
			var color := LINE_COLOR
			if _research and _research.is_researched(required):
				color = UpgradeButton.RESEARCHED_COLOR
				if not required.points.is_empty():
					color = Race.SKIN_COLORS[required.get_race()]
			color.a *= dim
			draw_line(from, to, color, LINE_WIDTH, true)


func _button_for(upgrade: Upgrade) -> UpgradeButton:
	for button: UpgradeButton in _buttons:
		if button.upgrade == upgrade:
			return button
	return null


func _local_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	rect.position -= global_position
	return rect


# Shows the card under the button, or above it where it would run off the bottom, kept
# inside the screen.
func _show_card(button: UpgradeButton) -> void:
	var card := %Card as UpgradeCard
	if not _research:
		return
	card.show_upgrade(button.upgrade, button.get_state(), _credits, _points)
	card.show()
	var screen := get_viewport_rect().size
	var rect := button.get_global_rect()
	var card_size := card.get_combined_minimum_size()
	var at := Vector2(rect.get_center().x - card_size.x * 0.5, rect.end.y + CARD_GAP)
	if at.y + card_size.y > screen.y:
		at.y = rect.position.y - CARD_GAP - card_size.y
	at.x = clampf(at.x, 0.0, screen.x - card_size.x)
	card.global_position = at


func _on_button_hovered(button: UpgradeButton) -> void:
	_hovered = button
	_show_card(button)


func _on_button_unhovered(button: UpgradeButton) -> void:
	if _hovered != button:
		return
	_hovered = null
	(%Card as Control).hide()


func _on_button_clicked(button: UpgradeButton) -> void:
	if _can_research and button.get_state() == Research.State.AVAILABLE:
		upgrade_clicked.emit(button.upgrade)


func _on_researched(_upgrade: Upgrade) -> void:
	_refresh()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_hovered = null
		(%Card as Control).hide()
