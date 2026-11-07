class_name PassengerCard
extends PanelContainer
## One passenger's card: their name and type, where they are going, their patience as a
## bar in their mood's colour, and what they are doing. While they ask for something, a
## button serves it. It only reads the passenger; the [Cabin] runs the ride.

## The serve button was pressed for [member passenger]'s open request.
signal serve_pressed

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


func _ready() -> void:
	var bar := %PatienceBar as ProgressBar
	_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate()
	bar.add_theme_stylebox_override(&"fill", _fill)
	_show()


func _process(_delta: float) -> void:
	_show()


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
