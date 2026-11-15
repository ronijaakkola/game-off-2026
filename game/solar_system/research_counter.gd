class_name ResearchCounter
extends HBoxContainer
## The player's research points in the resource bar: for each [Race], a chip tinted in its
## skin colour with a flask in that colour and how many points of it the player has.
## Delivering a passenger earns one point of their race, whatever their rating. Each count
## has room for [constant ROOM], so the bar keeps its width until one passes 99. It shows
## the points of its [member ledger], and each change the ledger signals in a [ChangeChip]
## under its count: "+1" in the race's colour, or what was spent in red. Changes the same
## way while it shows add up in it. Points earned stay until [method commit], so they leave
## with the credits' and the rating's gains; points spent leave by themselves, with the
## credits' loss. It keeps no points of its own.

## The races in the order their chips show, the same as the research screen's trees.
const ORDER: Array[Race.Type] = [Race.Type.BLUE, Race.Type.GREEN, Race.Type.ORANGE]
## The flask's size, in pixels.
const ICON_SIZE := 12.0
## How strongly the chip behind each count is tinted in its race's colour.
const CHIP_TINT := 0.18
## Each chip's height, in pixels. It sets the pill's height too.
const CHIP_HEIGHT := 20.0
const FLASK := preload("res://shared/icons/flask_conical.svg")
## Each count always has room for this many digits.
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
		_show_counts()

var _labels: Dictionary[Race.Type, Label] = {}
var _chips: Dictionary[Race.Type, ChangeChip] = {}
# What each chip shows, which adds up changes while it shows, and the wait before one
# showing points spent leaves.
var _sums: Dictionary[Race.Type, int] = {}
var _holds: Dictionary[Race.Type, Tween] = {}
# The commit: the wait before the points earned leave.
var _commit: Tween


func _ready() -> void:
	for race: Race.Type in ORDER:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size.y = CHIP_HEIGHT
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Race.SKIN_COLORS[race], CHIP_TINT)
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
		icon.self_modulate = Race.SKIN_COLORS[race]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = &"PillLabel"
		label.text = "0"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.add_child(label)
		_labels[race] = label
		add_child(chip)
		var change := CHIP.instantiate() as ChangeChip
		change.target = chip
		label.add_child(change)
		_chips[race] = change
		var font := label.get_theme_font(&"font")
		var font_size := label.get_theme_font_size(&"font_size")
		label.custom_minimum_size.x = (
			font.get_string_size(ROOM, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
	if not ledger:
		ledger = Ledger.new()
	_show_counts()


## Lets the points earned leave: after [constant ChangeChip.HOLD_SECONDS], as the credits'
## and the rating's gains do.
func commit() -> void:
	if _commit:
		_commit.kill()
	_commit = create_tween()
	_commit.tween_interval(ChangeChip.HOLD_SECONDS)
	_commit.tween_callback(_release)


## The count of [param race]'s points, for something that points it out.
func get_count_label(race: Race.Type) -> Control:
	return _labels[race]


# Every count as the ledger has it. Before _ready() there are no labels yet, and _ready()
# shows them.
func _show_counts() -> void:
	for race: Race.Type in _labels:
		_labels[race].text = str(ledger.get_research(race))


# Points of [param race] went out, already gone from the ledger.
func _on_spent(race: Race.Type, amount: int) -> void:
	_show_change(race, -amount)


# Points of [param race] came in, already in the ledger.
func _on_earned(race: Race.Type, amount: int) -> void:
	_show_change(race, amount)


# Shows [param race]'s new count, and the [param change] to it in its chip. A change the
# same way as one still showing adds to it. Points earned stay until commit(), and one
# that comes during a commit's wait puts it off to the next; points spent leave after
# HOLD_SECONDS, as the credits' loss does.
func _show_change(race: Race.Type, change: int) -> void:
	var label := _labels.get(race) as Label
	if not label:
		return
	label.text = str(ledger.get_research(race))
	var chip := _chips[race]
	var sum := change
	if chip.is_showing() and signi(_sums[race]) == signi(change):
		sum += _sums[race]
	_sums[race] = sum
	var color := Race.SKIN_COLORS[race] if sum > 0 else ChangeChip.LOSS_COLOR
	chip.show_change("%+d" % sum, color)
	if _holds.has(race):
		_holds[race].kill()
	if sum > 0:
		if _commit:
			_commit.kill()
		return
	var hold := create_tween()
	hold.tween_interval(ChangeChip.HOLD_SECONDS)
	hold.tween_callback(chip.leave)
	_holds[race] = hold


# The chips showing points earned leave.
func _release() -> void:
	for race: Race.Type in _chips:
		if _sums.get(race, 0) > 0:
			_chips[race].leave()
