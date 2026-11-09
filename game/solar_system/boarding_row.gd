class_name BoardingRow
extends Control
## One passenger waiting at the planet the bus is docked at, as a row in the dock panel:
## their portrait (a [PassengerPhoto]), their name with where they are going under it (an
## icon of the planet and its name), their fare, and a button that picks them up. It reads
## the passenger when [member passenger] is set; a passenger's details don't change while
## they wait.
## The root is a slot that holds the row's place in the list, and the panel moves inside it,
## so the row can slide out to the right once they board. The slot is as tall as the panel
## and the gap under it, so it closes up without a jump when it shrinks.
## The pointer over the row, or a click on it, shows where they are going (the dock panel
## decides which), and the row whose trip shows is [member highlighted]: a border in their
## race's skin colour.

## The player pressed the button to pick up [member passenger].
signal board_pressed(passenger: Passenger)
## The player clicked the row anywhere but its button.
signal clicked(passenger: Passenger)

## Pixels under the row, kept in its slot.
const GAP := 4.0
## Seconds to slide out past the right edge, and then to close up.
const SLIDE_OUT_SECONDS := 0.3
const CLOSE_SECONDS := 0.2
# How far past the slot's right edge the panel ends up, so it ends out of sight.
const OFF_RIGHT := 32.0
## The highlighted row's border width, in pixels, and how much lighter its background is.
const HIGHLIGHT_BORDER := 2
const HIGHLIGHT_LIGHTEN := 0.06

var passenger: Passenger:
	set(value):
		passenger = value
		if is_node_ready():
			_show()

## Whether the button can be pressed: false while every seat is taken.
var can_board := true:
	set(value):
		can_board = value
		if is_node_ready():
			_show_button()

## Where the portrait is rendered. Set it before [member passenger].
var portrait_studio: PortraitStudio

## Whether the row's trip is the one shown: a border in their race's skin colour.
var highlighted := false:
	set(value):
		if value == highlighted:
			return
		highlighted = value
		if is_node_ready():
			_show_highlight()

var _leaving := false
var _slide: Tween


func _ready() -> void:
	resized.connect(_fit)
	(%Panel as Control).minimum_size_changed.connect(_fit)
	_show()
	_show_button()
	_fit()


## Whether the row is on its way out: its passenger boarded.
func is_leaving() -> bool:
	return _leaving


## Whether the pointer is over the row, its button included, and not over anything on top
## of it.
func is_hovered() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	var panel := %Panel as Control
	return hovered != null and (hovered == panel or panel.is_ancestor_of(hovered))


## Slides the row out past the right edge, closes up its place, and frees it.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	_show_button()
	if _slide:
		_slide.kill()
	var panel := %Panel as Control
	_slide = create_tween()
	(
		_slide
		. tween_property(panel, ^"position:x", size.x + OFF_RIGHT, SLIDE_OUT_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	(
		_slide
		. tween_property(self, ^"custom_minimum_size:y", 0.0, CLOSE_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_slide.tween_callback(queue_free)


func _show() -> void:
	if not passenger:
		return
	var photo := %PassengerPhoto as PassengerPhoto
	photo.studio = portrait_studio
	photo.passenger = passenger
	(%NameLabel as Label).text = passenger.name
	(%DestinationIcon as PlanetIcon).planet = passenger.destination
	(%DestinationLabel as Label).text = "To %s" % _destination_name()
	(%FareLabel as Label).text = "%d cr" % roundi(passenger.fare)


func _show_highlight() -> void:
	var panel := %Panel as Control
	panel.remove_theme_stylebox_override(&"panel")
	if not highlighted or not passenger or not passenger.destination:
		return
	var style := panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if not style:
		return
	style.set_border_width_all(HIGHLIGHT_BORDER)
	style.border_color = Race.SKIN_COLORS[passenger.race]
	style.bg_color.a += HIGHLIGHT_LIGHTEN
	panel.add_theme_stylebox_override(&"panel", style)


func _show_button() -> void:
	(%BoardButton as Button).disabled = _leaving or not can_board


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name


# The slot is as tall as the panel needs plus the gap, and the panel fills its width. Once
# the row leaves, the slot's height is the close-up tween's.
func _fit() -> void:
	var panel := %Panel as Control
	var needed := panel.get_combined_minimum_size()
	panel.size = Vector2(size.x, needed.y)
	if _leaving:
		return
	var slot := Vector2(needed.x, needed.y + GAP)
	if custom_minimum_size != slot:
		custom_minimum_size = slot


func _on_board_button_pressed() -> void:
	board_pressed.emit(passenger)


func _on_panel_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _leaving:
		accept_event()
		clicked.emit(passenger)
