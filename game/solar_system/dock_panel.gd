class_name DockPanel
extends Control
## What the bus can do at the station of the planet it is docked at, in the top right
## corner: the planet's icon and name, then its services: where the planet sells fuel, a
## button to hold down to refuel, and where it has a lab, a button to open the research
## screen. Under a faint line, who waits there: a button to pick up everyone that
## fits, and a row for each passenger, longest waiting first, with their portrait, how many
## on the bus are going their way too, and a button to pick them up. The services and Board
## all sit above the rows, so they stay in place as the rows come and go. The parent sets
## [member planet] while the bus is docked or charging.
## The board buttons are off while every seat is taken. It only asks: the parent picks the
## passenger up, pumps the fuel while [method is_fuel_held], and turns the fuel button on or
## off with [method show_fuel]. It slides in from the right when [member planet] is set and
## back out when it is cleared. A passenger who turns up while it shows opens a row, which
## shifts in from the right and fades in; a row whose passenger boards fades out, shifting
## right, then closes up. The card fits what it holds every frame, so it
## shrinks as smoothly as the row closes. The root is a slot of no height that marks the
## panel's place in the corner, and the card hangs down from it. So the card's top edge
## stays put however its height changes, with no container to re-sort a frame later and
## round the height to whole pixels. "Nobody waiting." ([EmptyLineLabel]) sits under the
## rows. At an abandoned planet a message says so in place of the line. The pointer over
## a row shows that passenger's trip, and a click on a row pins it, so it stays shown once
## the pointer leaves, until the row is clicked again, the passenger boards or the bus
## leaves. The row whose trip shows is highlighted. While [member beckon_boarding], the
## card's border glows and every row calls for its button to be pressed
## ([member BoardingRow.beckoning]), in one pulse: they brighten quickly and fade slowly,
## again and again, and hold bright under Reduce motion.
## Board all steps back to a plain button meanwhile, so there is one thing to press.
## While the player can pay for an upgrade they couldn't when they last closed the research
## screen ([method ResearchLab.has_unseen_upgrade]), the Research button has a thin outline
## in the Frameshift key's yellow on its edge, fainter than the key's and pulsing in step
## with it, and holding still under Reduce motion.
## While [member research_hidden], as through the tutorial and until research is
## open ([MechanicCall]), there is no Research button,
## and while [member fuel_hidden] no fuel button, while [member fuel_locked] one that is
## off, and while [member board_all_hidden] no Board all.

## The player pressed the button to pick up [param passenger]. Board all presses it for
## each one waiting, longest waiting first; the parent stops once the seats are full.
signal board_pressed(passenger: Passenger)
## The passenger whose trip to show changed to [param passenger]: the one whose row the
## pointer is over, else the pinned one, or null for nobody.
signal trip_previewed(passenger: Passenger)
## The player pressed the Research button, to research at [param at]'s lab.
signal research_pressed(at: Planet)
## The player pressed the Teleport button, to go through the shown planet's warp gate.
signal teleport_pressed
## The pointer came onto the Teleport button, or left it: the way through the gate shows
## from [param from] to [param to], or nowhere when both are null.
signal gate_previewed(from: Planet, to: Planet)

const ROW := preload("res://game/solar_system/boarding_row.tscn")
## Seconds to slide in from past the right edge, or back out.
const SLIDE_SECONDS := 0.35
## Seconds the Research row takes to grow in as research opens.
const RESEARCH_IN_SECONDS := 0.3
# How far past the slot's right edge the card goes, so it is out of sight.
const OFF_RIGHT := 32.0
## The seconds a beckoning pulse takes to brighten, and to fade before the next.
const BECKON_RISE_SECONDS := 0.3
const BECKON_FADE_SECONDS := 1.0
## The card's border while beckoning: its width in pixels, its colour at the height of a
## pulse, and its opacity between pulses, as a share of that.
const BECKON_BORDER := 2
const BECKON_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const BECKON_BORDER_LOW := 0.25
# The Research button's outline is a nudge, fainter than the Frameshift key's: its opacity
# swings between these.
const NUDGE_DIM := 0.15
const NUDGE_BRIGHT := 0.6

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
## Says whether there is a new upgrade to pay for, which lights the Research button.
@export var research_lab: ResearchLab
## Where a Board button pressed on a full bus says so.
@export var notices: NoticeStack

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

## Whether the card and its rows call for a pick-up, as in the tutorial's first step.
var beckon_boarding := false:
	set(value):
		if value == beckon_boarding:
			return
		beckon_boarding = value
		for row: BoardingRow in _rows.values():
			row.beckoning = value
		var board_all := %BoardAllButton as Button
		board_all.theme_type_variation = &"SmallButton" if value else &"SmallPrimaryButton"
		_start_beckon()

## Whether the Research button is hidden even at a planet with a lab.
var research_hidden := false:
	set(value):
		var revealed := research_hidden and not value
		research_hidden = value
		if is_node_ready():
			_show_services()
			if revealed and _shows_lab():
				_grow_in_research()
## Whether the fuel button is hidden even at a planet that sells fuel.
var fuel_hidden := false:
	set(value):
		fuel_hidden = value
		if is_node_ready():
			_show_services()

## Whether the fuel button shows but is off, reading what filling up would cost.
var fuel_locked := false
## Whether Board all is hidden.
var board_all_hidden := false:
	set(value):
		board_all_hidden = value
		if is_node_ready():
			_show_line()

# The planet whose line the panel lists. It stays while the panel slides out.
var _shown: Planet
var _rows: Dictionary[Passenger, BoardingRow] = {}
# 0 in place, 1 out past the right edge.
var _offset := 1.0
var _slide: Tween
# The passenger whose row was clicked, whose trip shows while no row is under the pointer.
var _pinned: Passenger
# The planet the gate leads to whose way shows, as last sent in gate_previewed.
var _gate_previewed: Planet
# The passenger whose trip shows, as last sent in trip_previewed.
var _previewed: Passenger
var _beckon: Tween
# What the Teleport button reads, or empty while its row hides.
var _teleport_text := ""
# How much of its height the Research row has, from 0 to 1, and the tween growing it in.
var _research_open := 1.0
var _research_in: Tween


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


## Whether the card is all the way in, not sliding.
func is_in() -> bool:
	return visible and is_zero_approx(_offset)


## The passengers in the shown line with a row.
func get_row_passengers() -> Array[Passenger]:
	var passengers: Array[Passenger] = []
	passengers.assign(_rows.keys())
	return passengers


## Whether the fuel button is held down.
func is_fuel_held() -> bool:
	return (%FuelButton as FuelButton).is_held()


## Shows the bus's fuel at [param fraction] of a full tank in the fuel button, with
## [param cost], the credits to fill it, and turns it on or off. Off, it lets go and reads
## [param reason] instead.
func show_fuel(fraction: float, cost: int, can_fuel: bool, reason: String) -> void:
	if fuel_locked and can_fuel:
		(%FuelButton as FuelButton).show_fuel(fraction, cost, false, FuelButton.IDLE_TEXT % cost)
		return
	(%FuelButton as FuelButton).show_fuel(fraction, cost, can_fuel, reason)


## Shows the Teleport button reading [param text], on or off by [param can_teleport], or
## hides its row while [param text] is empty.
func show_teleport(text: String, can_teleport: bool) -> void:
	var button := %TeleportButton as Button
	button.text = text
	button.disabled = not can_teleport
	var changed := _teleport_text.is_empty() != text.is_empty()
	_teleport_text = text
	if changed:
		_show_services()


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
		. set_ease(Tween.EASE_OUT)
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
		_show_services()
	_show_line()
	_sync_rows(false)


# The shown planet's services, and the line under them when there are any.
func _show_services() -> void:
	if not _shown:
		return
	var fuel := _shown.sells_fuel and not fuel_hidden
	var teleport := not _teleport_text.is_empty()
	(%FuelRow as Control).visible = fuel
	(%ResearchSlot as Control).visible = _shows_lab()
	(%TeleportSlot as Control).visible = teleport
	(%Services as Control).visible = fuel or _shows_lab() or teleport
	(%FuelRule as Control).visible = fuel or _shows_lab() or teleport
	# Under the fuel or Research row's gap when either shows.
	var gap := (
		(%Content as Control).get_theme_constant(&"separation") if fuel or _shows_lab() else 0
	)
	(%TeleportSlot as Control).add_theme_constant_override(&"margin_top", gap)
	_fit_research()


# The line's heading, Board all and rows, or at an abandoned planet the message instead.
func _show_line() -> void:
	var abandoned := _shown != null and _shown.abandoned
	(%WaitingLabel as Control).visible = not abandoned
	(%BoardAllButton as Control).visible = not abandoned and not board_all_hidden
	(%List as Control).visible = not abandoned
	(%AbandonedMessage as Control).visible = abandoned


# The Research row in its slot, under the fuel row's gap when that shows, with the slot as
# tall as the row has grown in.
func _fit_research() -> void:
	var row := %ResearchRow as Control
	var gap := 0.0
	if (%FuelRow as Control).visible:
		gap = (%Content as Control).get_theme_constant(&"separation")
	var needed := row.get_combined_minimum_size()
	row.offset_top = gap
	row.offset_bottom = gap + needed.y
	var slot := Vector2(needed.x, _research_open * (gap + needed.y))
	(%ResearchSlot as Control).custom_minimum_size = slot


# Research opened with the panel showing a lab: the Research row grows in under the fuel
# row while fading in, the card growing with it. Under Reduce motion it only fades.
func _grow_in_research() -> void:
	var row := %ResearchRow as Control
	if _research_in:
		_research_in.kill()
	row.modulate.a = 0.0
	_research_in = create_tween().set_parallel()
	_research_in.tween_property(row, ^"modulate:a", 1.0, RESEARCH_IN_SECONDS)
	if Settings.reduce_motion:
		return
	_set_research_open(0.0)
	(
		_research_in
		. tween_method(_set_research_open, 0.0, 1.0, RESEARCH_IN_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func _set_research_open(open: float) -> void:
	_research_open = open
	_fit_research()


# Whether the shown planet's lab has its Research button.
func _shows_lab() -> bool:
	return _shown != null and _shown.has_lab and not research_hidden


# Adds a row for each passenger new in line, which comes in when [param animated], and
# takes out those no longer in it.
func _sync_rows(animated := true) -> void:
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
		row.beckoning = beckon_boarding
		row.board_pressed.connect(board_pressed.emit)
		row.full_pressed.connect(_on_row_full_pressed)
		row.clicked.connect(_on_row_clicked)
		(%Rows as Control).add_child(row)
		_rows[passenger] = row
		if animated and visible:
			row.enter()
	(%EmptyLabel as EmptyLineLabel).show_empty(line.is_empty(), animated and visible)


# Pulses the card's border and the rows while beckoning, or puts the card back.
func _start_beckon() -> void:
	if _beckon:
		_beckon.kill()
		_beckon = null
	_set_beckon_glow(1.0)
	if not beckon_boarding:
		(%Card as Control).remove_theme_stylebox_override(&"panel")
		return
	if Settings.reduce_motion:
		return
	_beckon = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_beckon.tween_method(_set_beckon_glow, 0.0, 1.0, BECKON_RISE_SECONDS)
	_beckon.tween_method(_set_beckon_glow, 1.0, 0.0, BECKON_FADE_SECONDS)


func _set_beckon_glow(glow: float) -> void:
	for row: BoardingRow in _rows.values():
		row.beckon_glow = glow
	if not beckon_boarding:
		return
	var card := %Card as Control
	card.remove_theme_stylebox_override(&"panel")
	var style := card.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if not style:
		return
	style.set_border_width_all(BECKON_BORDER)
	style.border_color = BECKON_COLOR
	style.border_color.a *= lerpf(BECKON_BORDER_LOW, 1.0, glow)
	card.add_theme_stylebox_override(&"panel", style)


# Shows the way through the gate while the pointer is over the Teleport button, else the
# trip of the passenger whose row it is over, else the pinned one's, and nobody's once the
# bus has left. Highlights that row, and tells the parent when either changes.
func _preview() -> void:
	var gate_to: Planet = null
	if planet and not _teleport_text.is_empty() and (%TeleportButton as Button).is_hovered():
		gate_to = WarpGate.twin_of(planet)
	if gate_to != _gate_previewed:
		_gate_previewed = gate_to
		gate_previewed.emit(planet if gate_to else null, gate_to)
	var shown: Passenger = null
	if planet and not gate_to:
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
		row.along = cabin.count_going_to(row.passenger.destination) if cabin else 0
	var button := %BoardAllButton as Button
	button.text = "Board all" if free else "Bus full %d/%d" % [cabin.seats, cabin.seats]
	button.disabled = not free or _rows.is_empty()
	_nudge_research(_shows_lab() and research_lab != null and research_lab.has_unseen_upgrade())


## The fuel button, for a guide card to point at.
func get_fuel_button() -> Control:
	return %FuelButton


## The fuel row, its icon and button, for a guide card to point at.
func get_fuel_row() -> Control:
	return %FuelRow


## The warp row, its icon and button, for a guide card to point at.
func get_teleport_row() -> Control:
	return %TeleportRow


## The Research button's row, its icon included, for a guide card to point at.
func get_research_row() -> Control:
	return %ResearchRow


## The row of [param passenger] in the shown line, or null.
func get_row(passenger: Passenger) -> Control:
	return _rows.get(passenger)


## Whether the Research button's outline shows, as it does while there is an upgrade to pay
## for that the player hasn't seen on the research screen.
func is_research_nudging() -> bool:
	return (%ResearchNudge as CanvasItem).visible


# Shows the pulsing outline on the Research button, or hides it.
func _nudge_research(nudging: bool) -> void:
	var outline := %ResearchNudge as CanvasItem
	outline.visible = nudging
	if not nudging:
		return
	var pulse := 1.0
	if not Settings.reduce_motion:
		var seconds := Time.get_ticks_msec() / 1000.0
		pulse = 0.5 - 0.5 * cos(seconds * TAU / FrameshiftKey.PULSE_SECONDS)
	outline.self_modulate.a = lerpf(NUDGE_DIM, NUDGE_BRIGHT, pulse)


# Sizes the slot to the card's width, and hangs the card down from the slot, as tall as
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
	# Under Reduce motion the card stays in place and fades instead of sliding.
	var still := Settings.reduce_motion
	card.position = Vector2(0.0 if still else _offset * (card.size.x + OFF_RIGHT), 0.0)
	card.modulate.a = 1.0 - _offset if still else 1.0
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


func _on_research_button_pressed() -> void:
	if _shown:
		research_pressed.emit(_shown)


func _on_teleport_button_pressed() -> void:
	teleport_pressed.emit()


func _on_board_all_button_pressed() -> void:
	for passenger: Passenger in _rows.keys():
		board_pressed.emit(passenger)


func _on_row_full_pressed() -> void:
	if notices:
		notices.tell_bus_full()
