class_name DockPanel
extends Control
## What the bus can do at the planet it is docked at, just above the bus status in the
## bottom right corner. For now, who waits there: the planet's icon and name, a row for
## each passenger, longest waiting first, with their portrait and a button to pick them
## up, and a button to pick up everyone that fits. The parent sets [member planet] while
## the bus is docked or charging. The buttons are off while every seat is taken. It only
## asks; the parent picks the passenger up.
## It slides in from the right when [member planet] is set and back out when it is
## cleared. A row whose passenger boards slides out to the right, clipped by the card, and
## the card grows and shrinks smoothly to fit what it holds.
## The root is a slot that holds the panel's place above the bus status, and the card moves
## inside it.

## The player pressed the button to pick up [param passenger]. Board all presses it for
## each one waiting, longest waiting first; the parent stops once the seats are full.
signal board_pressed(passenger: Passenger)

const ROW := preload("res://game/solar_system/boarding_row.tscn")
## Seconds to slide in from past the right edge, or back out.
const SLIDE_SECONDS := 0.35
# How far past the slot's right edge the card goes, so it is out of sight.
const OFF_RIGHT := 32.0
# How fast the card's height follows its content, as an exponential rate per second.
const RESIZE_RATE := 14.0

## Who waits at each planet.
@export var waiting: WaitingPassengers:
	set(value):
		if waiting:
			waiting.changed.disconnect(_on_waiting_changed)
		waiting = value
		if waiting:
			waiting.changed.connect(_on_waiting_changed)
		if is_node_ready():
			_sync_rows()
## The seats the buttons check.
@export var cabin: Cabin

## Where the rows' portraits are rendered.
var portrait_studio: PortraitStudio

## The planet the bus is docked at, or null to slide the panel out.
var planet: Planet:
	set(value):
		if value == planet:
			return
		planet = value
		if is_node_ready():
			_show_planet()

# The planet whose line the panel lists. It stays while the panel slides out.
var _shown: Planet
var _rows: Dictionary[Passenger, BoardingRow] = {}
# The card's height on screen, easing toward what its content needs.
var _height := 0.0
# 0 in place, 1 out past the right edge.
var _offset := 1.0
var _slide: Tween


func _ready() -> void:
	_show_planet()


func _process(delta: float) -> void:
	if not visible:
		return
	var needed := _needed_size()
	_height = lerpf(_height, needed.y, 1.0 - exp(-RESIZE_RATE * delta))
	if absf(_height - needed.y) < 0.5:
		_height = needed.y
	_lay_out(needed)
	_show_buttons()


func _show_planet() -> void:
	if planet:
		if planet != _shown:
			_shown = planet
			_rebuild()
		visible = true
		var needed := _needed_size()
		_height = needed.y
		_lay_out(needed)
		_show_buttons()
		_slide_to(0.0)
	elif visible:
		_slide_to(1.0)


func _slide_to(offset: float) -> void:
	if _slide:
		_slide.kill()
	_slide = create_tween()
	(
		_slide
		. tween_property(self, ^"_offset", offset, SLIDE_SECONDS * absf(_offset - offset))
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT if offset == 0.0 else Tween.EASE_IN)
	)
	if offset > 0.0:
		_slide.tween_callback(_on_slid_out)


func _on_slid_out() -> void:
	visible = false
	_shown = null
	_rebuild()


# Lists the line at the shown planet afresh, with no rows sliding.
func _rebuild() -> void:
	var rows := %Rows as Control
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	_rows.clear()
	if _shown:
		(%PlanetIcon as PlanetIcon).planet = _shown
		(%NameLabel as Label).text = _planet_name(_shown)
	_sync_rows()


# Adds a row for each passenger new in line, and slides out those no longer in it.
func _sync_rows() -> void:
	var line: Array[Passenger] = []
	if waiting and _shown:
		line = waiting.get_waiting(_shown)
	for passenger: Passenger in _rows.keys():
		if passenger not in line:
			_rows[passenger].leave()
			_rows.erase(passenger)
	for passenger: Passenger in line:
		if _rows.has(passenger):
			continue
		var row := ROW.instantiate() as BoardingRow
		row.portrait_studio = portrait_studio
		row.passenger = passenger
		row.board_pressed.connect(board_pressed.emit)
		(%Rows as Control).add_child(row)
		_rows[passenger] = row
	(%EmptyLabel as Control).visible = line.is_empty()


func _show_buttons() -> void:
	var free := cabin.get_free_seats() > 0 if cabin else true
	for row: BoardingRow in _rows.values():
		row.can_board = free
	var button := %BoardAllButton as Button
	button.text = "Board all" if free else "Bus full %d/%d" % [cabin.seats, cabin.seats]
	button.disabled = not free or _rows.is_empty()


# What the card needs to show everything, margins included.
func _needed_size() -> Vector2:
	return (%Content as Control).get_combined_minimum_size() + _margins()


func _margins() -> Vector2:
	return (%Card as Control).get_theme_stylebox(&"panel").get_minimum_size()


# Sizes the slot to the card's width and its height now, and places the card in it. The
# content keeps its own height inside the clip, so a card shorter than it cuts it off.
func _lay_out(needed: Vector2) -> void:
	custom_minimum_size = Vector2(needed.x, _height)
	var width := maxf(size.x, needed.x)
	var card := %Card as Control
	card.position = Vector2(_offset * (width + OFF_RIGHT), 0.0)
	card.size = Vector2(width, _height)
	var content := %Content as Control
	content.position = Vector2.ZERO
	content.size = Vector2(width - _margins().x, content.get_combined_minimum_size().y)


func _planet_name(of: Planet) -> String:
	return of.display_name if of.display_name else String(of.name)


func _on_waiting_changed(changed_planet: Planet) -> void:
	if changed_planet == _shown:
		_sync_rows()


func _on_board_all_button_pressed() -> void:
	for passenger: Passenger in _rows.keys():
		board_pressed.emit(passenger)
