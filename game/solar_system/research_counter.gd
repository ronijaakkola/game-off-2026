class_name ResearchCounter
extends HBoxContainer
## The player's research points in the top right, left of the average rating: for each
## [Race], a token in its skin colour and how many points of it the player has. Delivering
## a passenger earns one point of their race, whatever their rating; the count pops as it
## goes up.

## The token's height, in pixels.
const ICON_SIZE := 14.0
## How much bigger a count pops, and the seconds up and back down.
const POP_SCALE := 1.35
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14

var _points: Dictionary[Race.Type, int] = {}
var _labels: Dictionary[Race.Type, Label] = {}
var _pops: Dictionary[Race.Type, Tween] = {}


func _ready() -> void:
	for value: int in Race.Type.values():
		var race := value as Race.Type
		_points[race] = 0
		var entry := HBoxContainer.new()
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_theme_constant_override(&"separation", 4)
		var icon := ResearchIcon.new()
		icon.color = Race.SKIN_COLORS[race]
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(icon)
		var label := Label.new()
		label.text = "0"
		entry.add_child(label)
		_labels[race] = label
		add_child(entry)


## Adds [param amount] points of [param race], and pops its count.
func add(race: Race.Type, amount := 1) -> void:
	_points[race] = get_points(race) + amount
	var label := _labels.get(race) as Label
	if not label:
		return
	label.text = str(_points[race])
	label.pivot_offset = label.get_combined_minimum_size() * 0.5
	if _pops.has(race):
		_pops[race].kill()
	var pop := create_tween()
	pop.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		pop
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_pops[race] = pop


## How many points of [param race] the player has.
func get_points(race: Race.Type) -> int:
	return _points.get(race, 0)
