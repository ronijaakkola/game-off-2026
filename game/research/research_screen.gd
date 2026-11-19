class_name ResearchScreen
extends Control
## The research screen: a modal over the whole screen, with the game paused under it while
## it is open. Its header holds its title, a "Game paused" tag, the player's credits,
## research points and rating in a resource bar of its own, and a Close button. Under it,
## the open research trees side by side, centred, each in a [ResearchColumn], with only
## their open stages' rows ([Research]): the rows line up across them, with a faint line
## across all of them between two stages, and the sheet is as tall as the rows that show.
## The pointer over an upgrade opens its tooltip at once. An upgrade held long enough only
## asks; the parent researches it. The close button and the pause action (Esc) close it,
## unless the pause menu is open over it: then Esc is the menu's. It holds the pause with
## the pause menu's [method PauseMenu.hold], so closing the menu over it leaves the game
## paused.
## It fades in as its sheet grows to full size, and fades out faster; under Reduce motion
## it only fades. What opened since it last showed fades in, once the sheet has: a tree's
## card and its tiles, or a stage's tiles, row by row.

## [param upgrade]'s tile was held long enough to research it.
signal upgrade_held(upgrade: Upgrade)
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

## Which upgrades are researched and which trees and stages are open. The parent sets it.
var research: Research
## The player's credits and research points, which the header shows and the tiles check.
## The parent sets it.
var ledger: Ledger:
	set(value):
		ledger = value
		(%ResourceBar as ResourceBar).ledger = value

var _trees: Array[ResearchTree] = []
var _columns: Array[ResearchColumn] = []
# The line between each two stages, by the stage under it; null where no tree reaches it.
var _dividers: Dictionary[int, Control] = {}
var _row_tops: Array[float] = []
# How many trees and stages showed open last time, so what opened since is revealed.
var _shown_trees := 0
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


func _exit_tree() -> void:
	# The pause is the screen's, so it goes with the screen.
	if visible:
		PauseMenu.release(self)


func _input(event: InputEvent) -> void:
	if not is_open() or PauseMenu.is_held_by_another(self):
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
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


## The title, for a guide card to point at.
func get_title() -> Control:
	return %TitleLabel


## The close button, for a guide card to point at.
func get_close_button() -> Control:
	return %CloseButton


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
	_place()


# Centres the open trees' cards in the room there is, each as tall as the open rows, the
# sheet as tall as them, and lays the lines between the open stages across them.
func _place() -> void:
	var area := %Trees as Control
	var shown: Array[ResearchColumn] = []
	for column: ResearchColumn in _columns:
		column.visible = not research or research.is_tree_open(column.tree)
		if column.visible:
			shown.append(column)
	for stage: int in _dividers:
		_dividers[stage].visible = not shown.is_empty() and _is_stage_shown(stage)
	if shown.is_empty():
		area.custom_minimum_size.y = 0.0
		return
	var last_row := _row_tops.size() - 1
	if research and research.get_open_stages() < Research.STAGES:
		last_row = mini(last_row, research.get_open_stages() * Research.ROWS_PER_STAGE - 1)
	var height := ResearchColumn.TILES_TOP + _row_tops[last_row] + UpgradeButton.SIZE.y
	height += CARD_BOTTOM
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
		column.queue_redraw()
	for stage: int in _dividers:
		var divider := _dividers[stage]
		var first_top := _row_tops[stage * Research.ROWS_PER_STAGE]
		var tiles_top := ResearchColumn.TILES_TOP - ResearchColumn.MARGIN.y
		var middle := tiles_top + first_top - (STAGE_GAP + 12.0) * 0.5
		divider.position = Vector2(left + ResearchColumn.MARGIN.x, middle)
		divider.size = Vector2(total - ResearchColumn.MARGIN.x * 2.0, 1.0)


func _is_stage_shown(stage: int) -> bool:
	return not research or research.is_stage_open(stage)


func _refresh() -> void:
	if not research or not ledger:
		return
	var points := ledger.get_research()
	for column: ResearchColumn in _columns:
		column.show_state(research, ledger.credits, points)
	_reveal_opened()


func _finish_closing() -> void:
	_closing = false
	hide()


# Reveals what opened since the screen last showed, once the screen has faded in: a tree's
# card and every tile it shows, and a stage's tiles in the trees that showed before.
func _reveal_opened() -> void:
	var trees := research.get_open_trees()
	var stages := research.get_open_stages()
	if trees == _shown_trees and stages == _shown_stages:
		return
	_place()
	var since := (Time.get_ticks_msec() - _opened_at) / 1000.0
	var delay := maxf(OPEN_SECONDS - since, 0.0)
	for column: ResearchColumn in _columns:
		var index := _trees.find(column.tree)
		if index >= trees:
			continue
		if index >= _shown_trees:
			_fade_in_card(column, delay)
			column.reveal_rows(0, delay, REVEAL_STAGGER)
		elif stages > _shown_stages:
			column.reveal_rows(_shown_stages * Research.ROWS_PER_STAGE, delay, REVEAL_STAGGER)
	_shown_trees = trees
	_shown_stages = stages


# Fades [param column]'s card in after [param delay].
func _fade_in_card(column: ResearchColumn, delay: float) -> void:
	column.modulate.a = 0.0
	var fade := column.create_tween()
	fade.tween_interval(delay)
	fade.tween_property(column, ^"modulate:a", 1.0, CARD_FADE_SECONDS).set_ease(Tween.EASE_OUT)


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
