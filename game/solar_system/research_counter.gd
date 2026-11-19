class_name ResearchCounter
extends HBoxContainer
## The player's research points in the resource bar: a chip tinted in the research
## points' colour with a flask in it and how many points the player has. Delivering a
## passenger earns one point, whatever their race or rating. The count has room for
## [constant ROOM], so the bar keeps its width until it passes 99. It shows the points of
## its [member ledger], and each change the ledger signals in a [ChangeChip] under its
## count: "+1" in the points' colour, or what was spent in red. Changes the same way while
## it shows add up in it. Points earned stay until [method commit], so they leave with the
## credits' and the rating's gains; points spent leave by themselves, with the credits'
## loss. It keeps no points of its own.

## The research points' colour, wherever they show: their flask, their chip's tint and
## a gain of them.
const COLOR := Color("c3a6ff")
## The flask's size, in pixels.
const ICON_SIZE := 12.0
## How strongly the chip behind the count is tinted in the points' colour.
const CHIP_TINT := 0.18
## The chip's height, in pixels. It sets the pill's height too.
const CHIP_HEIGHT := 20.0
const FLASK := preload("res://shared/icons/flask_conical.svg")
## The count always has room for this many digits.
const ROOM := "00"
const CHIP := preload("res://game/solar_system/change_chip.tscn")

## The points it shows. Until one is set, or when set to null, it shows a ledger
## of its own, so the scene runs by itself.
var ledger: Ledger:
	set(value):
		if ledger:
			ledger.research_earned.disconnect(_on_earned)
			ledger.research_spent.disconnect(_on_spent)
		ledger = value if value else Ledger.new()
		ledger.research_earned.connect(_on_earned)
		ledger.research_spent.connect(_on_spent)
		_show_count()

var _label: Label
var _change: ChangeChip
# What the change chip shows, which adds up changes while it shows, and the wait before
# one showing points spent leaves.
var _sum := 0
var _hold: Tween
# The commit: the wait before the points earned leave.
var _commit: Tween


func _ready() -> void:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size.y = CHIP_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR, CHIP_TINT)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	chip.add_theme_stylebox_override(&"panel", style)
	var entry := HBoxContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_theme_constant_override(&"separation", 4)
	chip.add_child(entry)
	var icon := TextureRect.new()
	icon.texture = FLASK
	icon.self_modulate = COLOR
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(icon)
	_label = Label.new()
	_label.theme_type_variation = &"PillLabel"
	_label.text = "0"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.add_child(_label)
	add_child(chip)
	_change = CHIP.instantiate() as ChangeChip
	_change.target = chip
	_label.add_child(_change)
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	_label.custom_minimum_size.x = (
		font.get_string_size(ROOM, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	if not ledger:
		ledger = Ledger.new()
	_show_count()


## Lets the points earned leave: after [constant ChangeChip.HOLD_SECONDS], as the credits'
## and the rating's gains do.
func commit() -> void:
	if _commit:
		_commit.kill()
	_commit = create_tween()
	_commit.tween_interval(ChangeChip.HOLD_SECONDS)
	_commit.tween_callback(_release)


## The count, for something that points it out.
func get_count_label() -> Control:
	return _label


# The count as the ledger has it. Before _ready() there is no label yet, and _ready()
# shows it.
func _show_count() -> void:
	if _label:
		_label.text = str(ledger.get_research())


# Points went out, already gone from the ledger.
func _on_spent(amount: int) -> void:
	_show_change(-amount)


# Points came in, already in the ledger.
func _on_earned(amount: int) -> void:
	_show_change(amount)


# Shows the new count, and the [param change] to it in the chip. A change the same way as
# one still showing adds to it. Points earned stay until commit(), and one that comes
# during a commit's wait puts it off to the next; points spent leave after HOLD_SECONDS,
# as the credits' loss does.
func _show_change(change: int) -> void:
	if not _label:
		return
	_label.text = str(ledger.get_research())
	var sum := change
	if _change.is_showing() and signi(_sum) == signi(change):
		sum += _sum
	_sum = sum
	_change.show_change("%+d" % sum, COLOR if sum > 0 else ChangeChip.LOSS_COLOR)
	if _hold:
		_hold.kill()
	if sum > 0:
		if _commit:
			_commit.kill()
		return
	_hold = create_tween()
	_hold.tween_interval(ChangeChip.HOLD_SECONDS)
	_hold.tween_callback(_change.leave)


# The chip showing points earned leaves.
func _release() -> void:
	if _sum > 0:
		_change.leave()
