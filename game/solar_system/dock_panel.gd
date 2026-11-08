class_name DockPanel
extends Control
## What the bus can do at the planet it is docked at, just above the bus status in the
## bottom right corner: the planet's icon and name, then, where the planet sells fuel, a
## button to hold down to refuel and a faint line under it, then who waits there: a row
## for each passenger, longest waiting first, with their portrait and a button to pick them
## up, and a button to pick up everyone that fits. The parent sets [member planet] while
## the bus is docked or charging. The board buttons are off while every seat is taken. It
## only asks: the parent picks the passenger up, pumps the fuel while
## [method is_fuel_held], and turns the fuel button on or off with [method show_fuel].
## It slides in from the right when [member planet] is set and back out when it is
## cleared. A row whose passenger boards slides out to the right, clipped by the card, then
## closes up. The card fits what it holds every frame, so it shrinks as smoothly as the row
## closes and Board all, at the bottom, stays put.
## The root is a slot of no height that marks the panel's place just above the bus status,
## and the card hangs upward from it. So the card's bottom edge stays put however its
## height changes, with no container to re-sort a frame later and round the height to whole
## pixels. "Nobody waiting." sits under the rows, so a row sliding out uncovers it and the
## card only shrinks.
## The pointer over a row shows that passenger's trip, and a click on a row pins it, so it
## stays shown once the pointer leaves, until the row is clicked again, the passenger
## boards or the bus leaves. The row whose trip shows is highlighted.

## The player pressed the button to pick up [param passenger]. Board all presses it for
## each one waiting, longest waiting first; the parent stops once the seats are full.
signal board_pressed(passenger: Passenger)
## The passenger whose trip to show changed to [param passenger]: the one whose row the
## pointer is over, else the pinned one, or null for nobody.
signal trip_previewed(passenger: Passenger)

const ROW := preload("res://game/solar_system/boarding_row.tscn")
## Seconds to slide in from past the right edge, or back out.
const SLIDE_SECONDS := 0.35
# How far past the slot's right edge the card goes, so it is out of sight.
const OFF_RIGHT := 32.0

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
# 0 in place, 1 out past the right edge.
var _offset := 1.0
var _slide: Tween
# The passenger whose row was clicked, whose trip shows while no row is under the pointer.
var _pinned: Passenger
# The passenger whose trip shows, as last sent in trip_previewed.
var _previewed: Passenger


func _ready() -> void:
	# Rows close up in a tween, which runs after _process, and the content's container
	# sorts at the end of the frame. Fitting the card again as the content's size changes
	# keeps the card and Board all in step with it in that same frame, not a frame behind.
	(%Content as Control).minimum_size_changed.connect(_on_content_resized)
	_show_planet()


func _process(_delta: float) -> void:
	if not visible:
		return
	_lay_out()
	_show_buttons()
	_preview()


## Pins [param passenger]'s trip, so it shows while the pointer is over no row, as a click
## on their row does. Null unpins.
func pin(passenger: Passenger) -> void:
	_pinned = passenger
	_preview()


## Whether the fuel button is held down.
func is_fuel_held() -> bool:
	return (%FuelButton as FuelButton).is_held()


## Shows the bus's fuel at [param fraction] of a full tank in the fuel button, with
## [param cost], the credits to fill it, and turns it on or off. Off, it lets go and reads
## [param reason] instead.
func show_fuel(fraction: float, cost: int, can_fuel: bool, reason: String) -> void:
	(%FuelButton as FuelButton).show_fuel(fraction, cost, can_fuel, reason)


func _show_planet() -> void:
	if planet:
		if planet != _shown:
			_shown = planet
			_rebuild()
		visible = true
		_lay_out()
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
	_pinned = null
	if _shown:
		(%PlanetIcon as PlanetIcon).planet = _shown
		(%NameLabel as Label).text = _planet_name(_shown)
		(%FuelButton as Control).visible = _shown.sells_fuel
		(%FuelRule as Control).visible = _shown.sells_fuel
	_sync_rows()


# Adds a row for each passenger new in line, and slides out those no longer in it.
func _sync_rows() -> void:
	var line: Array[Passenger] = []
	if waiting and _shown:
		line = waiting.get_waiting(_shown)
	for passenger: Passenger in _rows.keys():
		if passenger not in line:
			_rows[passenger].highlighted = false
			_rows[passenger].leave()
			_rows.erase(passenger)
			if passenger == _pinned:
				_pinned = null
	for passenger: Passenger in line:
		if _rows.has(passenger):
			continue
		var row := ROW.instantiate() as BoardingRow
		row.portrait_studio = portrait_studio
		row.passenger = passenger
		row.board_pressed.connect(board_pressed.emit)
		row.clicked.connect(_on_row_clicked)
		(%Rows as Control).add_child(row)
		_rows[passenger] = row
	(%EmptyLabel as Control).visible = line.is_empty()


# Shows the trip of the passenger whose row the pointer is over, else the pinned one's, and
# nobody's once the bus has left. Highlights that row, and tells the parent when it changes.
func _preview() -> void:
	var shown: Passenger = null
	if planet:
		for passenger: Passenger in _rows:
			if _rows[passenger].is_hovered():
				shown = passenger
		if not shown and _rows.has(_pinned):
			shown = _pinned
	for passenger: Passenger in _rows:
		_rows[passenger].highlighted = passenger == shown
	if shown != _previewed:
		_previewed = shown
		trip_previewed.emit(shown)


func _show_buttons() -> void:
	var free := cabin.get_free_seats() > 0 if cabin else true
	for row: BoardingRow in _rows.values():
		row.can_board = free
	var button := %BoardAllButton as Button
	button.text = "Board all" if free else "Bus full %d/%d" % [cabin.seats, cabin.seats]
	button.disabled = not free or _rows.is_empty()


# Sizes the slot to the card's width, and hangs the card upward from the slot, as tall as
# its content needs. The clip and the content are placed here too rather than by the card's
# next sort, a frame later, which would leave them a frame behind the card.
func _lay_out() -> void:
	var style := (%Card as Control).get_theme_stylebox(&"panel")
	var margins := style.get_minimum_size()
	var content := %Content as Control
	var needed := content.get_combined_minimum_size()
	custom_minimum_size = Vector2(needed.x + margins.x, 0.0)
	var inner := Vector2(maxf(size.x, custom_minimum_size.x) - margins.x, needed.y)
	var card := %Card as Control
	card.size = inner + margins
	card.position = Vector2(_offset * (card.size.x + OFF_RIGHT), -card.size.y)
	var clip := %Clip as Control
	clip.position = style.get_offset()
	clip.size = inner
	content.position = Vector2.ZERO
	content.size = inner


func _planet_name(of: Planet) -> String:
	return of.display_name if of.display_name else String(of.name)


func _on_content_resized() -> void:
	if visible:
		_lay_out()


func _on_waiting_changed(changed_planet: Planet) -> void:
	if changed_planet == _shown:
		_sync_rows()


# A click on a row pins its trip, and a second click unpins it.
func _on_row_clicked(passenger: Passenger) -> void:
	pin(null if passenger == _pinned else passenger)


func _on_board_all_button_pressed() -> void:
	for passenger: Passenger in _rows.keys():
		board_pressed.emit(passenger)
