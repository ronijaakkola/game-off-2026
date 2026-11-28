class_name ResearchScreen
extends Control
## The research screen: a modal over the whole screen, with the game paused under it while
## it is open. Its header holds its title, a "Game paused" tag, the player's credits,
## research points and rating in a resource bar of its own, and a Close button, with the
## Research grant a button before it that buys a research point ([member grant_shown]). Under it,
## the research trees side by side, centred, each in a [ResearchColumn], with only their
## open stages' rows ([Research]): the rows line up across them, with a faint line
## across all of them between two stages, and the sheet is as tall as the rows that show.
## Under the last open stage, while a stage is still to open, the same line with a tag in its
## middle, a lock and "Requires promotion", and the trees' lines to that stage's upgrades
## run on past it to their cards' bottom edges.
## The pointer over an upgrade opens its tooltip at once. An upgrade held long enough only
## asks; the parent researches it. The close button and the pause action (Esc) close it,
## unless the pause menu is open over it: then Esc is the menu's. Until the player has
## researched their first upgrade, while they can pay for one, neither closes it and
## the close button is off, with a tooltip saying why. It holds the pause with
## the pause menu's [method PauseMenu.hold], so closing the menu over it leaves the game
## paused.
## It fades in as its sheet grows to full size, and fades out faster; under Reduce motion
## it only fades. What opened since it last showed fades in, once the sheet has: every
## tree's card and its tiles as research opens, or a stage's tiles, row by row.

## [param upgrade]'s tile was held long enough to research it.
signal upgrade_held(upgrade: Upgrade)
## The player pressed the Research grant's button, to buy a research point; the parent sells it.
signal grant_pressed
## It closed.
signal closed

## Pixels from one row's tiles to the next within a stage, and the extra room between two
## stages, where the line between them runs.
const ROW_PITCH := 64.0
const STAGE_GAP := 36.0
## Pixels between two trees' cards.
const COLUMN_GAP := 18.0
const LINE_COLOR := Color(1, 1, 1, 0.12)
## Pixels between the last row's tiles and the card's bottom edge.
const CARD_BOTTOM := 16.0
## What the tag on the line over a stage still to open says, the tag's height, colours and
## the gap between it and the line either side, and the room the cards keep under the line.
const PROMOTION_TEXT := "Requires promotion"
const PROMOTION_HEIGHT := 20.0
const PROMOTION_FILL := Color("2a2450")
const PROMOTION_INK := Color(0.957, 0.945, 1, 0.651)
const PROMOTION_GAP := 8
const PROMOTION_ROOM := 26.0
const LOCK := preload("res://shared/icons/lock.svg")
## Seconds to fade in, for the sheet to grow from [constant OPEN_SCALE], and to fade out.
const FADE_IN_SECONDS := 0.2
const OPEN_SECONDS := 0.25
const OPEN_SCALE := 0.97
const CLOSE_SECONDS := 0.15
## Seconds between one row's tiles starting to show and the next's, as a stage opens, and
## for a tree's card to fade in.
const REVEAL_STAGGER := 0.04
const CARD_FADE_SECONDS := 0.2
## The close button's side margins, so it is a 32 px square round its 14 px icon.
const CLOSE_MARGIN := 9.0
## What the Research grant's button says, with the credits a research point costs.
const GRANT_TEXT := "+1 for %d credits"

## Which upgrades are researched, and whether research and which stages are open. The
## parent sets it.
var research: Research
## The player's credits and research points, which the header shows and the tiles check.
## The parent sets it.
var ledger: Ledger:
	set(value):
		ledger = value
		(%ResourceBar as ResourceBar).ledger = value
## Whether the header has the Research grant's button, left of Close. The parent sets it.
var grant_shown := false:
	set(value):
		grant_shown = value
		(%GrantButton as Button).visible = value
## The credits a research point costs there: the button says so, and is off while the player
## has less. The parent sets it.
var grant_credits := 0:
	set(value):
		grant_credits = value
		(%GrantButton as Button).text = GRANT_TEXT % value

var _trees: Array[ResearchTree] = []
var _columns: Array[ResearchColumn] = []
# The line between each two stages, by the stage under it; null where no tree reaches it.
var _dividers: Dictionary[int, Control] = {}
var _row_tops: Array[float] = []
# The line over the stage still to open, with its tag.
var _promotion: Control
# Whether research and how many stages showed open last time, so what opened since is
# revealed.
var _shown_opened := false
var _shown_stages := 1
var _fade: Tween
var _closing := false
var _opened_at := 0


func _ready() -> void:
	hide()
	# A square close button: the theme's buttons are padded for a label.
	var close := %CloseButton as Button
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var box := close.get_theme_stylebox(state).duplicate() as StyleBox
		box.content_margin_left = CLOSE_MARGIN
		box.content_margin_right = CLOSE_MARGIN
		close.add_theme_stylebox_override(state, box)
	(%GrantButton as Button).pressed.connect(grant_pressed.emit)


func _exit_tree() -> void:
	# The pause is the screen's, so it goes with the screen.
	if visible:
		PauseMenu.release(self)


func _input(event: InputEvent) -> void:
	if not is_open() or PauseMenu.is_held_by_another(self):
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if not _is_first_visit():
			close()


func _process(_delta: float) -> void:
	if visible:
		_refresh()


## Shows [param trees] side by side, builds them afresh if they changed, and pauses the
## game.
func open(trees: Array[ResearchTree]) -> void:
	if trees != _trees:
		_build(trees)
	if _fade:
		_fade.kill()
	_closing = false
	show()
	PauseMenu.hold(self)
	_opened_at = Time.get_ticks_msec()
	modulate.a = 0.0
	var sheet := %Margin as Control
	sheet.pivot_offset = sheet.size * 0.5
	sheet.scale = Vector2.ONE
	_fade = create_tween().set_parallel()
	_fade.tween_property(self, ^"modulate:a", 1.0, FADE_IN_SECONDS).set_ease(Tween.EASE_OUT)
	if not Settings.reduce_motion:
		sheet.scale = Vector2.ONE * OPEN_SCALE
		(
			_fade
			. tween_property(sheet, ^"scale", Vector2.ONE, OPEN_SECONDS)
			. set_trans(Tween.TRANS_QUART)
			. set_ease(Tween.EASE_OUT)
		)
	_refresh()


## Lets the game run again at once, and fades out.
func close() -> void:
	if not is_open():
		return
	_closing = true
	PauseMenu.release(self)
	closed.emit()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, ^"modulate:a", 0.0, CLOSE_SECONDS).set_ease(Tween.EASE_OUT)
	_fade.tween_callback(_finish_closing)


## Whether it shows, and isn't on its way out.
func is_open() -> bool:
	return visible and not _closing


## Shows the credits and ratings earned since the last commit in its resource bar.
func commit() -> void:
	(%ResourceBar as ResourceBar).commit()


## The "Game paused" tag, for a guide card to point at.
func get_paused_tag() -> Control:
	return %PausedTag


## The tile of [param upgrade], or null where no tree shown has it.
func get_button(upgrade: Upgrade) -> UpgradeButton:
	for column: ResearchColumn in _columns:
		var button := column.get_button(upgrade)
		if button:
			return button
	return null


func _build(trees: Array[ResearchTree]) -> void:
	_trees = trees.duplicate()
	var area := %Trees as Control
	for child: Node in area.get_children():
		area.remove_child(child)
		child.queue_free()
	_columns.clear()
	_dividers.clear()
	var rows := 0
	for tree: ResearchTree in trees:
		for upgrade: Upgrade in tree.upgrades:
			rows = maxi(rows, upgrade.tier + 1)
	_row_tops.clear()
	for tier: int in rows:
		_row_tops.append(tier * ROW_PITCH + Research.get_stage_of_row(tier) * STAGE_GAP)
	for tree: ResearchTree in trees:
		var column := ResearchColumn.new()
		column.build(tree, _row_tops)
		column.upgrade_held.connect(upgrade_held.emit)
		area.add_child(column)
		_columns.append(column)
	for stage: int in range(1, Research.STAGES):
		var first_row := stage * Research.ROWS_PER_STAGE
		if first_row < rows:
			_dividers[stage] = _make_line()
			area.add_child(_dividers[stage])
	_promotion = _make_promotion_line()
	area.add_child(_promotion)
	_place()


# Centres the trees' cards, once research is open, in the room there is, each as tall as
# the open rows, the sheet as tall as them, and lays the lines between the open stages
# across them. Under the last open stage, the line over the stage still to open, which the
# cards reach past, with the trees' lines running on to their bottom edges.
func _place() -> void:
	var area := %Trees as Control
	var shown: Array[ResearchColumn] = []
	for column: ResearchColumn in _columns:
		column.visible = not research or research.is_opened()
		if column.visible:
			shown.append(column)
	# The stage still to open, if the trees have one.
	var next := research.get_open_stages() if research else Research.STAGES
	var locked := _dividers.has(next) and not shown.is_empty()
	for stage: int in _dividers:
		_dividers[stage].visible = not shown.is_empty() and _is_stage_shown(stage)
	_promotion.visible = locked
	if shown.is_empty():
		area.custom_minimum_size.y = 0.0
		return
	var last_row := _row_tops.size() - 1
	if research and research.get_open_stages() < Research.STAGES:
		last_row = mini(last_row, research.get_open_stages() * Research.ROWS_PER_STAGE - 1)
	var height := ResearchColumn.TILES_TOP + _row_tops[last_row] + UpgradeButton.SIZE.y
	height += CARD_BOTTOM
	var cut := INF
	if locked:
		cut = ResearchColumn.TILES_TOP + _line_top(next)
		height = cut + PROMOTION_ROOM
	# The cards reach their margin above the area, so the tiles' tops line up with it.
	area.custom_minimum_size.y = height - ResearchColumn.MARGIN.y
	var count := shown.size()
	var total := count * ResearchColumn.WIDTH + (count - 1) * COLUMN_GAP
	var left := floorf((area.size.x - total) * 0.5)
	for i: int in count:
		var column := shown[i]
		var x := left + i * (ResearchColumn.WIDTH + COLUMN_GAP)
		column.position = Vector2(x, -ResearchColumn.MARGIN.y)
		column.size = Vector2(ResearchColumn.WIDTH, height)
		column.cut_y = height if locked else INF
		column.queue_redraw()
	for stage: int in _dividers:
		var divider := _dividers[stage]
		var tiles_top := ResearchColumn.TILES_TOP - ResearchColumn.MARGIN.y
		var middle := tiles_top + _line_top(stage)
		divider.position = Vector2(left + ResearchColumn.MARGIN.x, middle)
		divider.size = Vector2(total - ResearchColumn.MARGIN.x * 2.0, 1.0)
		if stage == next:
			_promotion.position = divider.position - Vector2(0, PROMOTION_HEIGHT * 0.5)
			_promotion.size = Vector2(divider.size.x, PROMOTION_HEIGHT)


# How far under the top of the tiles the line over [param stage] runs.
func _line_top(stage: int) -> float:
	return _row_tops[stage * Research.ROWS_PER_STAGE] - (STAGE_GAP + 12.0) * 0.5


func _is_stage_shown(stage: int) -> bool:
	return not research or research.is_stage_open(stage)


func _refresh() -> void:
	if not research or not ledger:
		return
	var points := ledger.get_research()
	for column: ResearchColumn in _columns:
		column.show_state(research, ledger.credits, points)
	var first := _is_first_visit()
	(%CloseButton as Button).disabled = first
	(%CloseTooltip as Tooltip).muted = not first
	(%GrantButton as Button).disabled = ledger.credits < grant_credits
	_reveal_opened()


# Whether the player has yet to research their first upgrade and can pay for one.
func _is_first_visit() -> bool:
	if not research or not ledger or research.has_researched_any():
		return false
	var points := ledger.get_research()
	for tree: ResearchTree in _trees:
		for upgrade: Upgrade in tree.upgrades:
			if research.get_state(upgrade, ledger.credits, points) == Research.State.AVAILABLE:
				return true
	return false


func _finish_closing() -> void:
	_closing = false
	hide()


# Reveals what opened since the screen last showed, once the screen has faded in: every
# tree's card and every tile it shows as research opens, or a stage's tiles.
func _reveal_opened() -> void:
	var opened := research.is_opened()
	var stages := research.get_open_stages()
	if opened == _shown_opened and stages == _shown_stages:
		return
	_place()
	var since := (Time.get_ticks_msec() - _opened_at) / 1000.0
	var delay := maxf(OPEN_SECONDS - since, 0.0)
	for column: ResearchColumn in _columns:
		if not opened:
			continue
		if not _shown_opened:
			_fade_in_card(column, delay)
			column.reveal_rows(0, delay, REVEAL_STAGGER)
		elif stages > _shown_stages:
			column.reveal_rows(_shown_stages * Research.ROWS_PER_STAGE, delay, REVEAL_STAGGER)
	_shown_opened = opened
	_shown_stages = stages


# Fades [param column]'s card in after [param delay].
func _fade_in_card(column: ResearchColumn, delay: float) -> void:
	column.modulate.a = 0.0
	var fade := column.create_tween()
	fade.tween_interval(delay)
	fade.tween_property(column, ^"modulate:a", 1.0, CARD_FADE_SECONDS).set_ease(Tween.EASE_OUT)


# The line over a stage still to open: a faint line either side of a tag with a lock and
# what the stage takes.
func _make_promotion_line() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", PROMOTION_GAP)
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PROMOTION_FILL
	style.border_color = LINE_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(roundi(PROMOTION_HEIGHT * 0.5))
	style.content_margin_left = 8
	style.content_margin_right = 8
	tag.add_theme_stylebox_override(&"panel", style)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 4)
	var icon := TextureRect.new()
	icon.texture = LOCK
	icon.modulate = PROMOTION_INK
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(10, 10)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = &"SmallStrongLabel"
	label.add_theme_color_override(&"font_color", PROMOTION_INK)
	label.text = PROMOTION_TEXT
	content.add_child(label)
	tag.add_child(content)
	row.add_child(_make_line())
	row.add_child(tag)
	row.add_child(_make_line())
	return row


# A faint line across every tree, between two stages.
func _make_line() -> Control:
	var line := Hairline.new()
	line.horizontal = true
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = LINE_COLOR
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


func _on_close_button_pressed() -> void:
	close()
