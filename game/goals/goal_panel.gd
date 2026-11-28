class_name GoalPanel
extends PanelContainer
## The player's goals, in the top right corner over the dock panel: "To get promoted", or
## the heading [method set_header] gives, and a row for each goal the [member tracker]
## has, in the order added. A goal added or removed while the panel shows comes in or goes
## as a quest does. Under a thin line
## and a flag, "Quests" and a row for each quest the [member quest_giver] shows, the one
## under way and those just finished. Each part shows only while it has rows, the line
## only between the two, and the panel only while there are any.
## The quests come in and go as the notices do ([SlideSlot]): the panel grows to make room
## while the part rises in and fades, and a quest that goes fades out before the panel
## closes over it. The first quest brings the whole part in, heading and all, and the last
## takes it out. What is already there when the panel is first shown doesn't move.
## It tells the [member quest_giver] which quest's row the pointer is on, so the map can
## show where that quest sends the bus.
## After a promotion the player chose to stay for, "Promoted!" and a card that jumps to the
## next system show in place of the goals ([method offer_jump]), while the bus is at a
## planet ([member bus_docked]). Alone in the panel, the card leaves and comes back with
## the whole panel, past the right edge as the dock panel does; over quests, it slides out
## of its place as the dock panel's rows do.

## The player pressed the jump button, to take the promotion's jump now.
signal jump_pressed

const ROW := preload("res://game/goals/goal_row.tscn")
const QUEST_ROW := preload("res://game/goals/quest_row.tscn")
## Pixels between the promotion goals and the quests' part.
const PART_GAP := 8
const HEADER := "To get promoted"
const PROMOTED_HEADER := "Promoted!"
## Seconds to slide in from past the right edge, or back out, and how far past the edge it
## goes, in pixels, as the dock panel does.
const SLIDE_SECONDS := 0.35
const OFF_RIGHT := 32.0
## The goals giving way to the jump card. Seconds after The Boss's call has closed before
## it starts; seconds the goals take to fade out, and how far they sink, in pixels; seconds
## into that the card starts to come, the seconds it takes and how far under its place it
## starts; and the seconds the panel takes to fit the card. The quests come and go so.
const SWAP_BEAT := 0.3
const SWAP_OUT_SECONDS := 0.18
const SWAP_SINK := 6.0
const SWAP_IN_AFTER := 0.12
const SWAP_IN_SECONDS := 0.3
const SWAP_RISE := 8.0
const SWAP_FIT_SECONDS := 0.25

## The goals a promotion takes.
@export var tracker: GoalTracker:
	set(value):
		if tracker:
			tracker.goal_added.disconnect(_on_goal_added)
			tracker.goal_removed.disconnect(_on_goal_removed)
			tracker.goal_changed.disconnect(_on_goal_changed)
		tracker = value
		if tracker:
			tracker.goal_added.connect(_on_goal_added)
			tracker.goal_removed.connect(_on_goal_removed)
			tracker.goal_changed.connect(_on_goal_changed)
		if is_node_ready():
			_sync_rows()
## Whose quests show.
@export var quest_giver: QuestGiver:
	set(value):
		if quest_giver:
			quest_giver.quest_added.disconnect(_on_quest_added)
			quest_giver.quest_removed.disconnect(_on_quest_removed)
		quest_giver = value
		if quest_giver:
			quest_giver.quest_added.connect(_on_quest_added)
			quest_giver.quest_removed.connect(_on_quest_removed)
		if is_node_ready():
			_sync_rows()
## Where the quests' passengers' portraits are rendered.
@export var portrait_studio: PortraitStudio

## Whether the bus is at a planet, docked or charging. The jump card shows only then, as
## the dock panel does.
var bus_docked := true:
	set(value):
		if value == bus_docked:
			return
		bus_docked = value
		if is_node_ready():
			_show_parts()

var _rows: Dictionary[Goal, GoalRow] = {}
# Each goal's row sits in a slot of its own, and those still closing after their goal went
# keep the goals' part open until they have.
var _goal_slots: Dictionary[Goal, SlideSlot] = {}
var _closing_goals: Array[SlideSlot] = []
# The heading over the goals.
var _header := HEADER
# Each quest's row sits in a slot of its own.
var _quest_slots: Dictionary[Quest, SlideSlot] = {}
# The slots of the quests that went with the part as it closed, freed once it has, or as
# soon as a new quest comes.
var _left_slots: Array[SlideSlot] = []
# Whether the panel is in, or sliding in, rather than out past the right edge, and the
# tween that slides it.
var _slid_in := true
var _slide_tween: Tween
# Whether the jump card is offered, in place of the goals.
var _jump_offered := false
# The goals' rows still fading out as the jump card takes their place, freed once gone.
var _left_rows: Array[SlideSlot] = []
var _swap: Tween


func _ready() -> void:
	(%QuestSlot as SlideSlot).closed.connect(_on_quest_part_closed)
	(%GoalSlot as SlideSlot).closed.connect(_show_parts)
	(%GoalRows as Control).minimum_size_changed.connect(_fit_body)
	(%JumpButton as Button).pressed.connect(_on_jump_pressed)
	_sync_rows()


## Shows a card that jumps to [param system], under "Promoted!", in place of the goals; null
## takes it away. [param animated], while the bus is at a planet, the goals give way to it
## as the player watches ([method _swap_to_card]). Offer it before taking the goals away,
## so their rows are there to fade.
func offer_jump(system: StarSystem, animated := false) -> void:
	var card := %JumpButton as JumpCard
	_jump_offered = system != null
	if system:
		card.show_system(system)
	else:
		card.clear()
	if _swap:
		_swap.kill()
	if animated and _jump_offered and bus_docked and is_visible_in_tree():
		_swap_to_card()
	else:
		(%Header as Label).text = PROMOTED_HEADER if system else _header
		_show_body()
	_show_parts()


## Puts [param text] over the goals, in place of "To get promoted", morphing into it when
## [param animated] while the panel shows. The jump card keeps its own.
func set_header(text: String, animated := false) -> void:
	_header = text
	if _jump_offered:
		return
	var header := %Header as MorphLabel
	if animated and is_visible_in_tree():
		header.morph_to(text)
	else:
		header.text = text


# The goals' rows or the jump card, whichever is offered, at once and in place.
func _show_body() -> void:
	var rows := %GoalRows as Control
	var card := %JumpButton as Control
	_free_left_rows()
	for part: Control in [rows, card]:
		part.modulate.a = 1.0
	rows.position.y = 0.0
	card.position.y = 0.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	rows.visible = not _jump_offered
	card.visible = _jump_offered
	# It cuts its parts off only while they swap, so at rest what sticks out of them, such
	# as a rating goal's target mark, still shows.
	(%Body as Control).clip_contents = false
	_fit_body()


# The heading morphs into "Promoted!" while the goals fade out, sinking; as they go, the
# card rises into their place and fades in, and the panel eases to the card's height.
# Under Reduce motion nothing moves: the two fade, and the panel fits the card at once.
func _swap_to_card() -> void:
	var rows := %GoalRows as Control
	var card := %JumpButton as Control
	var still := Settings.reduce_motion
	var from := rows.get_combined_minimum_size().y
	var height := card.get_combined_minimum_size().y
	_set_body_height(from)
	_swap = create_tween()
	_swap.tween_interval(SWAP_BEAT)
	_swap.tween_callback((%Header as MorphLabel).morph_to.bind(PROMOTED_HEADER))
	_swap.tween_callback((%Body as Control).set_clip_contents.bind(true))
	_swap.set_parallel()
	_swap.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swap.tween_property(rows, ^"modulate:a", 0.0, SWAP_OUT_SECONDS)
	_swap.tween_callback(_show_card_under.bind(0.0 if still else SWAP_RISE)).set_delay(
		SWAP_IN_AFTER
	)
	var come := _swap.tween_property(card, ^"modulate:a", 1.0, SWAP_IN_SECONDS)
	come.set_trans(Tween.TRANS_QUART).set_delay(SWAP_IN_AFTER)
	if still:
		_swap.tween_callback(_set_body_height.bind(height)).set_delay(SWAP_IN_AFTER)
	else:
		_swap.tween_property(rows, ^"position:y", SWAP_SINK, SWAP_OUT_SECONDS)
		var rise := _swap.tween_property(card, ^"position:y", 0.0, SWAP_IN_SECONDS)
		rise.set_trans(Tween.TRANS_QUART).set_delay(SWAP_IN_AFTER)
		var fit := _swap.tween_method(_set_body_height, from, height, SWAP_FIT_SECONDS)
		# Growing, the room is there before the card shows; shrinking, it closes round it.
		if height < from:
			fit.set_ease(Tween.EASE_IN_OUT).set_delay(SWAP_IN_AFTER)
	_swap.chain().tween_callback(_show_body)


# The card, unseen, [param sunk] pixels under its place, to come in from there. It takes no
# press until it is in, so the dim a press gives it isn't faded over.
func _show_card_under(sunk: float) -> void:
	var card := %JumpButton as Control
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	card.position.y = sunk
	card.visible = true


func _set_body_height(height: float) -> void:
	(%Body as Control).custom_minimum_size.y = height


# The body is as tall as what it shows, unless the goals are giving way to the card.
func _fit_body() -> void:
	if _swap and _swap.is_running():
		return
	if _jump_offered:
		_set_body_height((%JumpButton as Control).get_combined_minimum_size().y)
	else:
		_set_body_height((%GoalRows as Control).get_combined_minimum_size().y)


## Whether the jump button shows.
func is_offering_jump() -> bool:
	return _jump_offered


## The button that jumps to the next system, for a hint to point at.
func get_jump_button() -> Control:
	return %JumpButton as Control


# Pressed once: the jump may wait for a stop under way to end.
func _on_jump_pressed() -> void:
	(%JumpButton as JumpCard).hold()
	jump_pressed.emit()


## The quests' part without the line over it: its heading and its rows.
func get_quests_part() -> Control:
	return (%QuestRows as Control).get_parent_control()


func _sync_rows() -> void:
	for row: Node in _goal_slots.values() + _quest_slots.values() + _left_slots:
		row.queue_free()
	_left_slots.clear()
	_rows.clear()
	_goal_slots.clear()
	_quest_slots.clear()
	if tracker:
		for goal: Goal in tracker.get_goals():
			_on_goal_added(goal)
	if quest_giver:
		for quest: Quest in quest_giver.get_quests():
			_add_quest(quest, false)
	_show_parts()


func _on_goal_added(goal: Goal) -> void:
	var row := ROW.instantiate() as GoalRow
	row.goal = goal
	var slot := SlideSlot.new()
	slot.add_child(row)
	(%GoalRows as Container).add_child(slot)
	_rows[goal] = row
	_goal_slots[goal] = slot
	var shown := is_visible_in_tree() and (%GoalSlot as SlideSlot).is_open()
	_show_parts()
	slot.open(shown and not _jump_offered)


func _on_goal_removed(goal: Goal) -> void:
	var slot: SlideSlot = _goal_slots.get(goal)
	if slot:
		_rows.erase(goal)
		_goal_slots.erase(goal)
		# Giving way to the jump card, it stays to fade out with the others.
		if _swap and _swap.is_running():
			_left_rows.append(slot)
		elif is_visible_in_tree() and not _jump_offered:
			_closing_goals.append(slot)
			slot.closed.connect(_on_goal_closed.bind(slot), CONNECT_ONE_SHOT)
			slot.close()
		else:
			slot.queue_free()
	_show_parts()


func _on_goal_closed(slot: SlideSlot) -> void:
	_closing_goals.erase(slot)
	slot.queue_free()
	_show_parts()


func _on_goal_changed(goal: Goal) -> void:
	var row: GoalRow = _rows.get(goal)
	if row:
		row.refresh()


func _on_quest_added(quest: Quest) -> void:
	_add_quest(quest, true)


## Shows a row for [param quest], which the [member quest_giver] doesn't give, as The Boss's
## pick-up is, coming in when [param animated]. Its goal is built.
func show_quest(quest: Quest, animated := true) -> void:
	if not _quest_slots.has(quest):
		_add_quest(quest, animated)


## Takes the row [method show_quest] added for [param quest] away.
func hide_quest(quest: Quest) -> void:
	_on_quest_removed(quest)


# Adds a row for [param quest] in a slot of its own. The first row brings the whole part
# in; a later one opens its own slot.
func _add_quest(quest: Quest, animated: bool) -> void:
	# The part may still be closing over the last quest: that one goes now, so it doesn't
	# come back with the part.
	_free_left_slots()
	var row := QUEST_ROW.instantiate() as QuestRow
	row.studio = portrait_studio
	row.quest = quest
	row.mouse_entered.connect(_on_quest_pointed.bind(quest, true))
	row.mouse_exited.connect(_on_quest_pointed.bind(quest, false))
	var slot := SlideSlot.new()
	slot.add_child(row)
	(%QuestRows as Container).add_child(slot)
	_quest_slots[quest] = slot
	var part := %QuestSlot as SlideSlot
	_show_parts()
	slot.open(animated and part.is_open())
	part.open(animated and is_visible_in_tree())


# The last row takes the whole part out with it; any other closes its own slot.
func _on_quest_removed(quest: Quest) -> void:
	var slot: SlideSlot = _quest_slots.get(quest)
	if not slot:
		return
	_quest_slots.erase(quest)
	_on_quest_pointed(quest, false)
	var part := %QuestSlot as SlideSlot
	if _quest_slots.is_empty():
		_left_slots.append(slot)
		part.close()
	else:
		slot.closed.connect(slot.queue_free, CONNECT_ONE_SHOT)
		slot.close()


# The pointer came onto [param quest]'s row, or left it.
func _on_quest_pointed(quest: Quest, on: bool) -> void:
	if on:
		quest_giver.pointed = quest
	elif quest_giver.pointed == quest:
		quest_giver.pointed = null


func _on_quest_part_closed() -> void:
	_free_left_slots()
	_show_parts()


func _free_left_rows() -> void:
	for row: SlideSlot in _left_rows:
		row.queue_free()
	_left_rows.clear()


func _free_left_slots() -> void:
	for slot: SlideSlot in _left_slots:
		slot.queue_free()
	_left_slots.clear()


# Each part stays until it has closed, so the panel doesn't go while it leaves. The goals
# come at once. The jump card comes and goes with the bus: alone in the panel, the whole
# panel slides out past the right edge and back, as the dock panel does; over quests, the
# card slides out of its place and back, as the dock panel's rows do.
func _show_parts() -> void:
	var slot := %GoalSlot as SlideSlot
	var asked := not _quest_slots.is_empty() or (%QuestSlot as SlideSlot).visible
	var no_rows := _rows.is_empty() and _closing_goals.is_empty()
	var alone := no_rows and is_offering_jump() and not asked
	var moving := no_rows and is_offering_jump() and is_visible_in_tree() and not alone
	if not no_rows or (is_offering_jump() and (bus_docked or alone)):
		slot.open(moving)
	else:
		slot.close(moving)
	var promotion := slot.visible
	(%Divider as Control).visible = promotion
	(%Section as MarginContainer).add_theme_constant_override(
		&"margin_top", PART_GAP if promotion else 0
	)
	if alone:
		if bus_docked and _slid_in:
			visible = true
		_slide(bus_docked)
	else:
		_slide(true)
		visible = promotion or asked


# Slides the whole panel in from past the right edge, or out past it and away, as the dock
# panel does, from wherever it is. Under Reduce motion it fades in place instead.
func _slide(shown: bool) -> void:
	if shown == _slid_in:
		return
	_slid_in = shown
	if _slide_tween:
		_slide_tween.kill()
	var rows := %Rows as Control
	var still := Settings.reduce_motion
	if not shown:
		if not is_visible_in_tree():
			_on_slid_out()
			return
		_slide_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
		_slide_tween.set_ease(Tween.EASE_OUT)
		if still:
			_slide_tween.tween_property(rows, ^"modulate:a", 0.0, SLIDE_SECONDS)
			_slide_tween.tween_property(self, ^"self_modulate:a", 0.0, SLIDE_SECONDS)
		else:
			var away := position.x + size.x + OFF_RIGHT
			_slide_tween.tween_property(self, ^"position:x", away, SLIDE_SECONDS)
		_slide_tween.chain().tween_callback(_on_slid_out)
		return
	visible = true
	if not is_visible_in_tree():
		return
	# Unseen for the frame the stack takes to lay it out, so it starts from its place.
	rows.modulate.a = 0.0
	self_modulate.a = 0.0
	await get_tree().process_frame
	if not _slid_in:
		return
	_slide_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	if still:
		_slide_tween.tween_property(rows, ^"modulate:a", 1.0, SLIDE_SECONDS)
		_slide_tween.tween_property(self, ^"self_modulate:a", 1.0, SLIDE_SECONDS)
		return
	rows.modulate.a = 1.0
	self_modulate.a = 1.0
	var rest := position.x
	position.x = rest + size.x + OFF_RIGHT
	_slide_tween.tween_property(self, ^"position:x", rest, SLIDE_SECONDS)


# Out of sight, it goes; the stack puts it back in place when it shows again.
func _on_slid_out() -> void:
	visible = false
	(%Rows as Control).modulate.a = 1.0
	self_modulate.a = 1.0
