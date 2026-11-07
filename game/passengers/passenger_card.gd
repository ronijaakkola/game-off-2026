class_name PassengerCard
extends Control
## One passenger's card: their name and type, where they are going, their patience as a
## bar in their mood's colour, and what they are doing. While they ask for something, a
## button serves it. It only reads the passenger; the [Cabin] runs the ride.
## The card slides in from past the left edge of the screen when the passenger boards, and
## back out past it when they get off, then folds its height away so the cards below it
## move up. The root is a slot that holds the card's place in the list, and the panel moves
## inside it.

## The serve button was pressed for [member passenger]'s open request.
signal serve_pressed
## The card has slid out and folded away after [method leave]. It can be freed.
signal left

## Seconds to slide in from past the left edge of the screen, and back out past it.
const SLIDE_IN_SECONDS := 0.4
const SLIDE_OUT_SECONDS := 0.3
## Seconds to fold the slot's height away once the card is out.
const FOLD_SECONDS := 0.2

const MOOD_COLORS: Dictionary[Passenger.Mood, Color] = {
	Passenger.Mood.HAPPY: Color(0.55, 0.85, 0.4),
	Passenger.Mood.OKAY: Color(0.98, 0.8, 0.38),
	Passenger.Mood.ANNOYED: Color(0.98, 0.55, 0.3),
	Passenger.Mood.FURIOUS: Color(0.95, 0.3, 0.4),
}
const MOOD_NAMES: Dictionary[Passenger.Mood, String] = {
	Passenger.Mood.HAPPY: "Happy",
	Passenger.Mood.OKAY: "Okay",
	Passenger.Mood.ANNOYED: "Annoyed",
	Passenger.Mood.FURIOUS: "Furious",
}

var passenger: Passenger:
	set(value):
		passenger = value
		_mood = -1
		if is_node_ready():
			_show()

# The bar's fill, this card's own copy, so its colour changes on this card alone.
var _fill: StyleBoxFlat
# The mood shown, so the colours change only when it does. -1 before the first show.
var _mood := -1
# How much of the card's height the slot keeps: 1 in the list, 0 folded away.
var _fold := 1.0
# The one tween that moves the panel and folds the slot, in turn.
var _motion: Tween


func _ready() -> void:
	var bar := %PatienceBar as ProgressBar
	_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate()
	bar.add_theme_stylebox_override(&"fill", _fill)
	_show()
	_fit_slot()


func _process(_delta: float) -> void:
	_show()
	_fit_slot()


## Starts the card past the left edge of the screen and slides it into place.
func slide_in() -> void:
	if _motion:
		_motion.kill()
	var panel := %Panel as Control
	panel.position.x = _off_left()
	_motion = create_tween()
	(
		_motion
		. tween_property(panel, ^"position:x", 0.0, SLIDE_IN_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


## Slides the card out past the left edge of the screen, then folds its height away, and
## emits [signal left]. The serve button stops working at once.
func leave() -> void:
	if _motion:
		_motion.kill()
	var panel := %Panel as Control
	(%ServeButton as Button).disabled = true
	_motion = create_tween()
	(
		_motion
		. tween_property(panel, ^"position:x", _off_left(), SLIDE_OUT_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	_motion.tween_method(_set_fold, 1.0, 0.0, FOLD_SECONDS).set_trans(Tween.TRANS_QUAD)
	_motion.tween_callback(left.emit)


# Where the panel sits just past the left edge of the screen, from the slot.
func _off_left() -> float:
	return -(global_position.x + (%Panel as Control).size.x + 8.0)


func _set_fold(value: float) -> void:
	_fold = value
	_fit_slot()


# The slot is as tall as the card, times the fold, and the panel fills its width.
func _fit_slot() -> void:
	var panel := %Panel as Control
	var size_needed := panel.get_combined_minimum_size()
	panel.size = size_needed
	var slot := Vector2(size_needed.x, size_needed.y * _fold)
	if custom_minimum_size != slot:
		custom_minimum_size = slot


func _show() -> void:
	if not passenger:
		return
	_set_text(%NameLabel, passenger.name)
	_set_text(%TypeLabel, passenger.type.display_name)
	_set_text(%DestinationLabel, "To %s" % _destination_name())
	(%PatienceBar as ProgressBar).value = passenger.get_patience_fraction()
	var mood := passenger.get_mood()
	if mood != _mood:
		_mood = mood
		_set_text(%MoodLabel, MOOD_NAMES[mood])
		(%MoodLabel as Label).add_theme_color_override(&"font_color", MOOD_COLORS[mood])
		_fill.bg_color = MOOD_COLORS[mood]
	_set_text(%ActivityLabel, passenger.activity)
	var button := %ServeButton as Button
	button.visible = passenger.request != null
	if passenger.request and button.text != passenger.request.serve_label:
		button.text = passenger.request.serve_label


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name


# Sets text only when it changes, since this runs every frame.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _on_serve_button_pressed() -> void:
	serve_pressed.emit()
