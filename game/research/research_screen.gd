class_name ResearchScreen
extends Control
## The research screen: a modal over the whole screen, with the game paused under it while
## it is open. Its header holds its title, a "Game paused" tag, the player's credits,
## research points and rating in a resource bar of its own, and a Close button. Under it,
## every research tree side by side, each in a [ResearchColumn], with their rows lined up
## so a line with a "Requires promotion" tag runs across all of them between two stages;
## the tag goes once the stage below opens. The pointer over an upgrade opens its tooltip at
## once. An upgrade held long enough only asks; the parent researches it. The close button
## and the pause action (Esc) close it, unless the pause menu is open over it: then Esc is
## the menu's. It holds the pause with the pause menu's [method PauseMenu.hold], so closing
## the menu over it leaves the game paused.
## It fades in as its sheet grows to full size, and fades out faster; under Reduce motion
## it only fades. A stage that opened since it last showed is revealed: its tag fades off
## the line, and its tiles fade in from silhouettes row by row.

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
const DIVIDER_HEIGHT := 20.0
const LINE_COLOR := Color(1, 1, 1, 0.12)
const TAG_COLOR := Color("2a2450")
const TAG_TEXT := "Requires promotion"
const LOCK := preload("res://game/research/icons/lock.svg")
## Seconds to fade in, for the sheet to grow from [constant OPEN_SCALE], and to fade out.
const FADE_IN_SECONDS := 0.2
const OPEN_SECONDS := 0.25
const OPEN_SCALE := 0.97
const CLOSE_SECONDS := 0.15
## Seconds between one row's tiles starting to show and the next's, as a stage opens, and
## for its tag to fade.
const REVEAL_STAGGER := 0.04
const TAG_FADE_SECONDS := 0.2
## The close button's side margins, so it is a 32 px square round its 14 px icon.
const CLOSE_MARGIN := 9.0

## Which upgrades are researched and which stages are open. The parent sets it.
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
var _tags: Dictionary[int, Control] = {}
var _row_tops: Array[float] = []
# How many stages showed open last time, so one that opened since is revealed.
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
	_tags.clear()
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
			_dividers[stage] = _make_divider(stage)
			area.add_child(_dividers[stage])
	_place()


# Centres the cards in the room there is, each as tall as it, and lays the lines between
# the stages across them.
func _place() -> void:
	var area := %Trees as Control
	if _columns.is_empty():
		return
	var count := _columns.size()
	var total := count * ResearchColumn.WIDTH + (count - 1) * COLUMN_GAP
	var left := floorf((area.size.x - total) * 0.5)
	for i: int in count:
		var column := _columns[i]
		# The cards reach their margin above the area, so the tiles' tops line up with it.
		var x := left + i * (ResearchColumn.WIDTH + COLUMN_GAP)
		column.position = Vector2(x, -ResearchColumn.MARGIN.y)
		column.size = Vector2(ResearchColumn.WIDTH, area.size.y + ResearchColumn.MARGIN.y)
		column.queue_redraw()
	for stage: int in _dividers:
		var divider := _dividers[stage]
		var first_top := _row_tops[stage * Research.ROWS_PER_STAGE]
		var tiles_top := ResearchColumn.TILES_TOP - ResearchColumn.MARGIN.y
		var middle := tiles_top + first_top - (STAGE_GAP + 12.0) * 0.5
		divider.position = Vector2(left + ResearchColumn.MARGIN.x, middle - DIVIDER_HEIGHT * 0.5)
		divider.size = Vector2(total - ResearchColumn.MARGIN.x * 2.0, DIVIDER_HEIGHT)


func _refresh() -> void:
	if not research or not ledger:
		return
	var points := ledger.get_all_research()
	for column: ResearchColumn in _columns:
		column.show_state(research, ledger.credits, points)
	_reveal_opened_stages()


func _finish_closing() -> void:
	_closing = false
	hide()


# Reveals each stage that opened since the screen last showed one, once the screen has
# faded in.
func _reveal_opened_stages() -> void:
	var open := 0
	while open < Research.STAGES and research.is_stage_open(open):
		open += 1
	if open <= _shown_stages:
		return
	var since := (Time.get_ticks_msec() - _opened_at) / 1000.0
	var delay := maxf(OPEN_SECONDS - since, 0.0)
	for stage: int in range(_shown_stages, open):
		for column: ResearchColumn in _columns:
			column.reveal_stage(stage, delay, REVEAL_STAGGER)
		if _tags.has(stage):
			_fade_tag(stage, delay)
	_shown_stages = open


# Fades the stage's tag off its line after [param delay], and the line's halves meet.
func _fade_tag(stage: int, delay: float) -> void:
	var tag := _tags[stage]
	var divider := _dividers[stage]
	var fade := create_tween()
	fade.tween_interval(delay)
	fade.tween_property(tag, ^"modulate:a", 0.0, TAG_FADE_SECONDS).set_ease(Tween.EASE_OUT)
	fade.tween_callback(tag.hide)
	fade.tween_callback(divider.add_theme_constant_override.bind(&"separation", 0))


# A line across every tree with the "Requires promotion" tag in its middle.
func _make_divider(stage: int) -> Control:
	var divider := HBoxContainer.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.add_theme_constant_override(&"separation", 8)
	divider.add_child(_make_line())
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.custom_minimum_size.y = DIVIDER_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = TAG_COLOR
	style.border_color = LINE_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	tag.add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	var icon := TextureRect.new()
	icon.texture = LOCK
	icon.modulate = Color(UpgradeButton.TEXT_COLOR, 0.651)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(10, 10)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = &"DimLabel"
	label.text = TAG_TEXT
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	tag.add_child(row)
	divider.add_child(tag)
	divider.add_child(_make_line())
	_tags[stage] = tag
	return divider


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
