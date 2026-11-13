class_name BoardingRow
extends Control
## One passenger waiting at the planet the bus is docked at, as a row in the dock panel:
## their portrait (a [PassengerPhoto]), their name with where they are going under it (an
## arrow, an icon of the planet and its name, then, fainter, how many on the bus are going
## there too, from [member along]), and a button that picks them up. It reads the passenger
## when [member passenger] is set; a passenger's details don't change while they wait.
## The root is a slot that holds the row's place in the list, and the panel moves inside it:
## a passenger who turns up opens the slot while the row shifts in from the right and fades
## in ([method enter]), and once they board the row fades out, shifting right, and the slot
## closes ([method leave]). The slot is as tall as the panel and the gap under it, so it
## opens and closes without a jump, and clips the panel meanwhile.
## The pointer over the row, or a click on it, shows where they are going (the dock panel
## decides which), and the row whose trip shows is [member highlighted]: a step lighter,
## with a border in their race's skin colour.
## A row that is [member beckoning] calls for its button to be pressed, as the tutorial
## does: the whole row shows the highlight's border and the button turns primary. The
## border glows and the button swells by [member beckon_glow], which the dock panel pulses;
## under Reduce motion the button doesn't swell.

## The player pressed the button to pick up [member passenger].
signal board_pressed(passenger: Passenger)
## The player clicked the row anywhere but its button.
signal clicked(passenger: Passenger)

## Pixels under the row, kept in its slot.
const GAP := 4.0
## Seconds to shift in and fade in, and to fade back out.
const ENTER_SECONDS := 0.3
const EXIT_SECONDS := 0.18
## Seconds for the slot to open to the row's height, and to close up once the row is out.
const GAP_SECONDS := 0.25
## How far right of its place the row starts, and how far right it ends, in pixels.
const ENTER_SHIFT := 12.0
const EXIT_SHIFT := 8.0
## The highlighted row's border width, in pixels, and how much lighter its background is.
const HIGHLIGHT_BORDER := 2
const HIGHLIGHT_LIGHTEN := 0.0706
## How much the beckoning button swells at the height of a pulse.
const BECKON_SCALE := 1.1
## A beckoning row's border opacity between pulses, and how much lighter its background is
## at the height of one, as a multiple of the highlight's.
const BECKON_BORDER_LOW := 0.35
const BECKON_LIGHTEN := 2.0

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

## How many on board or picked up are going where [member passenger] is. None shows nothing.
var along := 0:
	set(value):
		if value == along:
			return
		along = value
		if is_node_ready():
			_show_along()

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

## Whether the button calls to be pressed: primary, and swelling by [member beckon_glow].
var beckoning := false:
	set(value):
		if value == beckoning:
			return
		beckoning = value
		if is_node_ready():
			_show_beckon()

## How strongly a beckoning row glows now, from 0 between pulses to 1 at the height of one.
var beckon_glow := 1.0:
	set(value):
		beckon_glow = value
		if is_node_ready() and beckoning:
			_show_beckon()

var _leaving := false
# How much of the row's height the slot keeps: 1 in the list, 0 closed.
var _open := 1.0
# The tween that shifts and fades the panel, and the one that opens and closes the slot.
var _motion: Tween
var _gap: Tween


func _ready() -> void:
	resized.connect(_fit)
	(%Panel as Control).minimum_size_changed.connect(_fit)
	_show()
	_show_button()
	_show_along()
	_show_beckon()
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


## Opens the row's place in the list while the row shifts in from the right and fades in.
## Under Reduce motion it fades in in place, its place open at once.
func enter() -> void:
	_kill_motion()
	var panel := %Panel as Control
	panel.modulate.a = 0.0
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(panel, ^"modulate:a", 1.0, ENTER_SECONDS)
	if Settings.reduce_motion:
		return
	clip_contents = true
	_set_open(0.0)
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_open, 0.0, 1.0, GAP_SECONDS)
	_gap.tween_callback(func() -> void: clip_contents = false)
	panel.position.x = ENTER_SHIFT
	_motion.tween_property(panel, ^"position:x", 0.0, ENTER_SECONDS)


## Fades the row out, shifting right, from wherever it is, then closes up its place and
## frees it. Under Reduce motion it fades out in place and its place closes at once.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	beckoning = false
	_show_button()
	if _motion:
		_motion.kill()
	var panel := %Panel as Control
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(panel, ^"modulate:a", 0.0, EXIT_SECONDS)
	if not Settings.reduce_motion:
		_motion.tween_property(panel, ^"position:x", EXIT_SHIFT, EXIT_SECONDS)
	_motion.chain().tween_callback(_close_up)


func _close_up() -> void:
	if _gap:
		_gap.kill()
	if Settings.reduce_motion:
		queue_free()
		return
	clip_contents = true
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_open, _open, 0.0, GAP_SECONDS)
	_gap.tween_callback(queue_free)


func _kill_motion() -> void:
	for tween: Tween in [_motion, _gap]:
		if tween:
			tween.kill()


func _set_open(share: float) -> void:
	_open = share
	_fit()


func _show() -> void:
	if not passenger:
		return
	var photo := %PassengerPhoto as PassengerPhoto
	photo.studio = portrait_studio
	photo.passenger = passenger
	(%NameLabel as Label).text = passenger.name
	(%DestinationIcon as PlanetIcon).planet = passenger.destination
	(%DestinationLabel as Label).text = _destination_name()


# The border in their race's skin colour while highlighted or beckoning; beckoning, it
# glows by beckon_glow.
func _show_highlight() -> void:
	var panel := %Panel as Control
	panel.remove_theme_stylebox_override(&"panel")
	if not (highlighted or beckoning) or not passenger or not passenger.destination:
		return
	var style := panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if not style:
		return
	style.set_border_width_all(HIGHLIGHT_BORDER)
	style.border_color = Race.SKIN_COLORS[passenger.race]
	var lighten := HIGHLIGHT_LIGHTEN
	if beckoning:
		style.border_color.a = lerpf(BECKON_BORDER_LOW, 1.0, beckon_glow)
		lighten = lerpf(HIGHLIGHT_LIGHTEN, HIGHLIGHT_LIGHTEN * BECKON_LIGHTEN, beckon_glow)
	style.bg_color.a += lighten
	panel.add_theme_stylebox_override(&"panel", style)


func _show_along() -> void:
	var label := %AlongLabel as Label
	label.visible = along > 0
	label.text = "·  %d aboard" % along


func _show_button() -> void:
	(%BoardButton as Button).disabled = _leaving or not can_board


func _show_beckon() -> void:
	var button := %BoardButton as Button
	button.theme_type_variation = &"SmallPrimaryButton" if beckoning else &"SmallButton"
	var swell := beckon_glow if beckoning and not Settings.reduce_motion else 0.0
	button.pivot_offset_ratio = Vector2(0.5, 0.5)
	button.scale = Vector2.ONE * lerpf(1.0, BECKON_SCALE, swell)
	_show_highlight()


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name


# The slot is as tall as the panel needs plus the gap, by how far open it is, and the panel
# fills its width.
func _fit() -> void:
	var panel := %Panel as Control
	var needed := panel.get_combined_minimum_size()
	panel.size = Vector2(size.x, needed.y)
	var slot := Vector2(needed.x, (needed.y + GAP) * _open)
	if custom_minimum_size != slot:
		custom_minimum_size = slot


func _on_board_button_pressed() -> void:
	board_pressed.emit(passenger)


func _on_panel_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _leaving:
		accept_event()
		clicked.emit(passenger)
