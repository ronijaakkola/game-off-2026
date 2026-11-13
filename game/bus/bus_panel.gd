class_name BusPanel
extends SidePanel
## The open bus's panel down the right side of the screen: a row for each of the bus's
## stats, with its value and, once upgrades change it, how much they add in all ("+20%"),
## kept up to date as they change. Under them, the traits the bus has, by name, or "None
## yet.", which come and go as upgrades unlock them. It slides in when it opens and back out
## when it closes
## ([SidePanel]). Its close button only asks; the parent closes it.

## The close button was pressed.
signal close_pressed

## What upgrades add, in the green of the credits' gain.
const BONUS_COLOR := Color(0.55, 0.85, 0.4, 1)
## What modifiers take away, in the red of low fuel.
const PENALTY_COLOR := Color(0.95, 0.3, 0.4, 1)
## Each stat's name in its row, by [enum BusStats.Type]. A stat missing here shows its
## type's name.
const STAT_NAMES := {
	BusStats.Type.MAX_SPEED: "Top speed",
	BusStats.Type.FUEL_CAPACITY: "Fuel tank",
	BusStats.Type.SEATS: "Seats",
	BusStats.Type.PORTION_SIZE: "Portion size",
}
## How each stat's value shows, by type. A stat missing here shows two decimals.
const VALUE_FORMATS := {
	BusStats.Type.FUEL_CAPACITY: "%.0f",
	BusStats.Type.PORTION_SIZE: "%.1fx",
}
## Each trait's name in its row, by [enum BusTraits.Type]. A trait missing here shows its
## type's name.
const TRAIT_NAMES := {
	BusTraits.Type.FUEL_FORECAST: "Fuel forecast",
	BusTraits.Type.WAITING_MARKERS: "Waiting markers",
	BusTraits.Type.PILLOWS: "Pillows",
	BusTraits.Type.SLEEPING_PODS: "Sleeping pods",
	BusTraits.Type.GAMING_SYSTEM: "Space Invaders",
	BusTraits.Type.ENTERTAINMENT_SYSTEM: "In-Flight Movies",
	BusTraits.Type.FOOD_DISPENSER: "Food Replicator",
	BusTraits.Type.SERVING_ROBOTS: "Waiter Droids",
}

## The width of each row's delta slot, wide enough for "+100%".
const BONUS_WIDTH := 44.0

var _bus: FrameshiftBus
var _open := false
# Each stat's value and bonus labels, by type.
var _value_labels: Dictionary[BusStats.Type, Label] = {}
var _bonus_labels: Dictionary[BusStats.Type, Label] = {}
# Each trait's row, shown while the bus has it, by type.
var _trait_labels: Dictionary[BusTraits.Type, Label] = {}


## Shows [param bus]'s stats and slides in, unless already open.
func open(bus: FrameshiftBus) -> void:
	if bus != _bus:
		_watch(bus)
	_open = true
	_show_stats()
	_show_traits()
	slide_in()


## Slides out past the right edge, then hides: fast with [param swapped], when another
## panel takes its place.
func close(swapped := false) -> void:
	_open = false
	slide_out(swapped)


## Whether it is open: from [method open] until [method close], while it slides out too.
func is_open() -> bool:
	return _open


# Makes a row for each of the bus's stats and traits, and follows their changes.
func _watch(bus: FrameshiftBus) -> void:
	if _bus:
		for type: BusStats.Type in _value_labels:
			_bus.get_stats().get_stat(type).changed.disconnect(_show_stats)
		_bus.get_stats().get_traits().changed.disconnect(_on_trait_changed)
	_bus = bus
	_make_trait_rows()
	bus.get_stats().get_traits().changed.connect(_on_trait_changed)
	var rows := %StatRows as Control
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	_value_labels.clear()
	_bonus_labels.clear()
	for value: int in BusStats.Type.values():
		var type := value as BusStats.Type
		rows.add_child(_make_row(type))
		bus.get_stats().get_stat(type).changed.connect(_show_stats)


func _make_row(type: BusStats.Type) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	var name_label := _make_label("NameLabel")
	name_label.text = STAT_NAMES.get(type, String(BusStats.Type.keys()[type]).capitalize())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _make_label("ValueLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	var bonus_label := _make_label("BonusLabel")
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bonus_label.custom_minimum_size.x = BONUS_WIDTH
	row.add_child(bonus_label)
	_value_labels[type] = value_label
	_bonus_labels[type] = bonus_label
	return row


# A row for each trait, in the order of [enum BusTraits.Type], after "None yet.".
func _make_trait_rows() -> void:
	var rows := %TraitRows as Control
	for label: Label in _trait_labels.values():
		rows.remove_child(label)
		label.queue_free()
	_trait_labels.clear()
	for value: int in BusTraits.Type.values():
		var type := value as BusTraits.Type
		var label := _make_label("TraitLabel")
		label.text = TRAIT_NAMES.get(type, String(BusTraits.Type.keys()[type]).capitalize())
		rows.add_child(label)
		_trait_labels[type] = label


func _make_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.theme_type_variation = &"SmallLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _show_stats() -> void:
	for type: BusStats.Type in _value_labels:
		var stat := _bus.get_stats().get_stat(type)
		_value_labels[type].text = _value_text(type, stat)
		var bonus := _bonus_labels[type]
		bonus.text = _bonus_text(type, stat)
		var color := PENALTY_COLOR if bonus.text.begins_with("-") else BONUS_COLOR
		bonus.add_theme_color_override(&"font_color", color)


func _show_traits() -> void:
	var traits := _bus.get_stats().get_traits()
	var any := false
	for type: BusTraits.Type in _trait_labels:
		_trait_labels[type].visible = traits.has(type)
		any = any or traits.has(type)
	(%NoTraitsLabel as Control).visible = not any


func _value_text(type: BusStats.Type, stat: Stat) -> String:
	if type == BusStats.Type.SEATS:
		return str(_bus.get_stats().get_seats())
	return (VALUE_FORMATS.get(type, "%.2f") as String) % stat.get_value()


# How much the modifiers add to the base in all: whole seats for the seats ("+1"), a whole
# percent for the rest. Nothing when they add up to none either way.
func _bonus_text(type: BusStats.Type, stat: Stat) -> String:
	if type == BusStats.Type.SEATS:
		var seats := _bus.get_stats().get_seats() - roundi(stat.base)
		return "%+d" % seats if seats != 0 else ""
	if stat.base == 0.0:
		return ""
	var percent := roundi((stat.get_value() / stat.base - 1.0) * 100.0)
	return "%+d%%" % percent if percent != 0 else ""


func _on_trait_changed(_type: BusTraits.Type) -> void:
	_show_traits()


func _on_close_button_pressed() -> void:
	close_pressed.emit()
