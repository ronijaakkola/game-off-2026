class_name ResearchCounter
extends HBoxContainer
## The player's research points in the resource bar: for each [Race], a chip tinted in its
## skin colour with a flask in that colour and how many points of it the player has.
## Delivering a passenger earns one point of their race, whatever their rating; the count
## pops as it goes up. Each count has room for [constant ROOM], so the bar keeps its width
## until one passes 99. It shows the points of its [member ledger] and pops each count the
## ledger signals as earned; a count spent just changes. It keeps no points of its own.

## The flask's size, in pixels.
const ICON_SIZE := 12.0
## How strongly the chip behind each count is tinted in its race's colour.
const CHIP_TINT := 0.18
## Each chip's height, in pixels. It sets the pill's height too.
const CHIP_HEIGHT := 20.0
const FLASK := preload("res://game/solar_system/icons/flask_conical.svg")
## Each count always has room for this many digits.
const ROOM := "00"
## How much bigger a count pops, and the seconds up and back down.
const POP_SCALE := 1.35
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14

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
var _pops: Dictionary[Race.Type, Tween] = {}


func _ready() -> void:
	for value: int in Race.Type.values():
		var race := value as Race.Type
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
		var font := label.get_theme_font(&"font")
		var font_size := label.get_theme_font_size(&"font_size")
		label.custom_minimum_size.x = (
			font.get_string_size(ROOM, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
	if not ledger:
		ledger = Ledger.new()
	_show_counts()


# Every count as the ledger has it. Before _ready() there are no labels yet, and _ready()
# shows them.
func _show_counts() -> void:
	for race: Race.Type in _labels:
		_labels[race].text = str(ledger.get_research(race))


# Points of [param race] went out, already gone from the ledger: shows the new count.
func _on_spent(race: Race.Type, _amount: int) -> void:
	var label := _labels.get(race) as Label
	if label:
		label.text = str(ledger.get_research(race))


# Points of [param race] came in, already in the ledger: shows the new count and pops it.
func _on_earned(race: Race.Type, _amount: int) -> void:
	var label := _labels.get(race) as Label
	if not label:
		return
	label.text = str(ledger.get_research(race))
	label.pivot_offset = label.get_combined_minimum_size() * 0.5
	if _pops.has(race):
		_pops[race].kill()
	if Settings.reduce_motion:
		label.scale = Vector2.ONE
		return
	var pop := create_tween()
	pop.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		pop
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_pops[race] = pop
