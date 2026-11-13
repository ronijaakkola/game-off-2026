class_name ResearchColumn
extends Control
## One research tree in the research screen, on a faint card of its own: its title and a
## chip in its race's colour counting the upgrades researched of all it has, over the tree
## drawn top to bottom, each upgrade at its tier and column, centred in the column. A line
## runs from each upgrade to each one it requires, centre to centre under the tiles: lit and
## glowing in the race's colour once that one is researched, a little brighter while it
## can be researched, and faint otherwise. The parent places the rows, so every column's
## stages line up, and tells it each upgrade's state, which each tile's tooltip says
## ([UpgradeTooltip]). It passes on a tile held long enough; the parent researches it.

## [param upgrade]'s tile was held long enough to research it.
signal upgrade_held(upgrade: Upgrade)

## The tree's room inside the card, and the card's margin round it.
const INNER_WIDTH := 324.0
const MARGIN := Vector2(12, 8)
## Where the tiles start under the card's top edge, below the header.
const TILES_TOP := 48.0
## Pixels from one column's tiles to the next.
const COLUMN_PITCH := 68.0
const CARD_COLOR := Color(1, 1, 1, 0.07)
const CARD_BORDER := Color(1, 1, 1, 0.12)
const CARD_RADIUS := 8
const LINE_WIDTH := 2.0
const LIT_WIDTH := 3.0
## A lit line's glow: the race's colour blurred as a design tool blurs it ([SoftGlow]).
const GLOW_BLUR := 10.0
## How strong a lit line is over its glow.
const LIT_ALPHA := 0.8
const FAINT_LINE := Color(1, 1, 1, 0.08)
const OPEN_LINE := Color(1, 1, 1, 0.14)
const FLASK := preload("res://shared/icons/flask_conical.svg")

## The full width of the card.
const WIDTH := INNER_WIDTH + MARGIN.x * 2.0

var _tree: ResearchTree
var _buttons: Array[UpgradeButton] = []
var _research: Research
# What the tooltips were last filled for, so they change only when that does.
var _credits := -1
var _points: Dictionary[Race.Type, int] = {}
var _count: Label
var _card := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.bg_color = CARD_COLOR
	_card.border_color = CARD_BORDER
	_card.set_border_width_all(1)
	_card.set_corner_radius_all(CARD_RADIUS)


## Builds [param tree], each tier's tiles at the height [param row_tops] gives it, from the
## top of the tiles.
func build(tree: ResearchTree, row_tops: Array[float]) -> void:
	_tree = tree
	custom_minimum_size.x = WIDTH
	var race := _race()
	var accent: Color = Race.SKIN_COLORS[race]
	add_child(_make_header(tree.title, accent))
	var columns := 0
	for upgrade: Upgrade in tree.upgrades:
		columns = maxi(columns, upgrade.column + 1)
	var tree_width := (columns - 1) * COLUMN_PITCH + UpgradeButton.SIZE.x
	var left := MARGIN.x + (INNER_WIDTH - tree_width) * 0.5
	for upgrade: Upgrade in tree.upgrades:
		var button := UpgradeButton.new()
		button.upgrade = upgrade
		button.position = Vector2(
			left + upgrade.column * COLUMN_PITCH, TILES_TOP + row_tops[upgrade.tier]
		)
		button.held.connect(upgrade_held.emit.bind(upgrade))
		add_child(button)
		_buttons.append(button)


## Shows each upgrade's state from [param research], with [param credits] and
## [param points] the player has. Only what changed is redrawn, so the parent can call it
## every frame.
func show_state(research: Research, credits: int, points: Dictionary[Race.Type, int]) -> void:
	_research = research
	var paid_with_changed := credits != _credits or points != _points
	_credits = credits
	_points = points.duplicate()
	var changed := false
	var done := 0
	for button: UpgradeButton in _buttons:
		var upgrade := button.upgrade
		var state := research.get_state(upgrade, credits, points)
		var before := button.get_state()
		button.show_state(state, _lacks_points(upgrade, points))
		if before != state or paid_with_changed:
			UpgradeTooltip.show(button.get_info_tooltip(), upgrade, state, credits, points)
		changed = changed or before != state
		if state == Research.State.RESEARCHED:
			done += 1
	var text := "%d/%d" % [done, _buttons.size()]
	if _count.text != text:
		_count.text = text
	if changed:
		queue_redraw()


## Fades in the tiles of [param stage] from silhouettes after [param delay] seconds, each
## row [param stagger] seconds after the one above.
func reveal_stage(stage: int, delay: float, stagger: float) -> void:
	var first_row := stage * Research.ROWS_PER_STAGE
	for button: UpgradeButton in _buttons:
		if Research.get_stage(button.upgrade) == stage:
			button.reveal(delay + (button.upgrade.tier - first_row) * stagger)


## The tile of [param upgrade], or null where it isn't in this tree.
func get_button(upgrade: Upgrade) -> UpgradeButton:
	for button: UpgradeButton in _buttons:
		if button.upgrade == upgrade:
			return button
	return null


func _draw() -> void:
	draw_style_box(_card, Rect2(Vector2.ZERO, size))
	# Faint lines first, so a lit one crossing them stays whole.
	for lit: bool in [false, true]:
		for button: UpgradeButton in _buttons:
			for required: Upgrade in button.upgrade.requires:
				var from := get_button(required)
				if from and _is_lit(required) == lit:
					_draw_link(from, button)


func _draw_link(from: UpgradeButton, to: UpgradeButton) -> void:
	var start := from.position + UpgradeButton.SIZE * 0.5
	var end := to.position + UpgradeButton.SIZE * 0.5
	if _is_lit(from.upgrade):
		var glow := SoftGlow.line(LIT_WIDTH, GLOW_BLUR)
		var across := float(glow.get_height())
		draw_set_transform(start, (end - start).angle())
		var along := Rect2(0.0, -across * 0.5, start.distance_to(end), across)
		draw_texture_rect(glow, along, false, from.get_accent())
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_line(start, end, Color(from.get_line_color(), LIT_ALPHA), LIT_WIDTH, true)
		return
	var state := from.get_state()
	var open := state == Research.State.AVAILABLE or state == Research.State.UNAFFORDABLE
	draw_line(start, end, OPEN_LINE if open else FAINT_LINE, LINE_WIDTH, true)


func _is_lit(upgrade: Upgrade) -> bool:
	return _research != null and _research.is_researched(upgrade)


func _lacks_points(upgrade: Upgrade, points: Dictionary[Race.Type, int]) -> bool:
	for race: Race.Type in upgrade.points:
		if points.get(race, 0) < upgrade.points[race]:
			return true
	return false


# The race whose points most of the tree costs, for its chip.
func _race() -> Race.Type:
	var counts: Dictionary[Race.Type, int] = {}
	for upgrade: Upgrade in _tree.upgrades:
		var race := upgrade.get_race()
		counts[race] = counts.get(race, 0) + 1
	var best := Race.Type.BLUE
	for race: Race.Type in counts:
		if counts[race] > counts.get(best, 0):
			best = race
	return best


# The title at the left and the progress chip at the right.
func _make_header(title: String, accent: Color) -> Control:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.position = Vector2(MARGIN.x, MARGIN.y + 2.0)
	header.size = Vector2(INNER_WIDTH, 20)
	var label := Label.new()
	label.theme_type_variation = &"StrongLabel"
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(label)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.18)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	chip.add_theme_stylebox_override(&"panel", style)
	chip.custom_minimum_size.y = 20
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	var icon := TextureRect.new()
	icon.texture = FLASK
	icon.modulate = accent
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(11, 11)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_count = Label.new()
	_count.theme_type_variation = &"SmallStrongLabel"
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count)
	chip.add_child(row)
	header.add_child(chip)
	return header
