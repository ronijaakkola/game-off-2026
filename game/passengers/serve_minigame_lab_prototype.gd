extends Node
## PROTOTYPE, throwaway: a lab for trying the serve minigames ([ServeMinigamePrototype])
## without flying anywhere, opened from the main menu's debug panel. A cabin of passengers
## who never arrive keep asking for something at the pace picked, on the real cards, and
## the buttons beside them pick the game every serve button plays. It counts how long each
## request waited from asked to served, so the games compare by a number as well as by feel.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const SEATS := 6
## A trip so long nobody is ever late.
const TRIP_SECONDS := 100000.0
const DESTINATIONS: Array[String] = ["Ember", "Terra", "Moon", "Frost"]
const ICON_COLORS: Array[Color] = [
	Color(0.82, 0.58, 0.4),
	Color(0.5, 0.82, 0.34),
	Color(0.95, 0.93, 1.0),
	Color(1.0, 0.62, 0.74),
]
## Seconds between two requests, by the pace's name.
const PACES: Dictionary[String, float] = {"Calm": 3.0, "Busy": 1.5, "Frantic": 0.8}
const START_PACE := "Busy"

var _pace := PACES[START_PACE]
var _until_ask := 1.0
var _clock := 0.0
# When each open request was asked, on _clock.
var _asked: Dictionary[Passenger, float] = {}
var _waits: Array[float] = []
var _hint: Label
var _stats: Label


func _ready() -> void:
	var cabin := %Cabin as Cabin
	cabin.seats = SEATS
	for seat: int in SEATS:
		var destination := Planet.new()
		destination.display_name = DESTINATIONS[seat % DESTINATIONS.size()]
		destination.icon_color = ICON_COLORS[seat % DESTINATIONS.size()]
		add_child(destination)
		cabin.board(Passenger.new(COMMUTER, destination, TRIP_SECONDS, 40.0))
	cabin.docked = false
	var panel := %PassengerPanel as PassengerPanel
	panel.portrait_studio = %PortraitStudio as PortraitStudio
	panel.cabin = cabin
	_build_controls()
	_pick_game(ServeMinigamePrototype.mode)


func _process(delta: float) -> void:
	_clock += delta
	var passengers := (%Cabin as Cabin).get_passengers()
	_until_ask -= delta
	if _until_ask <= 0.0:
		_until_ask = _pace
		var idle := passengers.filter(func(p: Passenger) -> bool: return p.request == null)
		if not idle.is_empty():
			var passenger: Passenger = idle.pick_random()
			passenger.request = passenger.type.needs.pick_random()
			passenger.serving = 0.0
			passenger.activity = passenger.request.request_line
	for passenger: Passenger in passengers:
		if passenger.request and not _asked.has(passenger):
			_asked[passenger] = _clock
		elif not passenger.request and _asked.has(passenger):
			_waits.append(_clock - _asked[passenger])
			_asked.erase(passenger)
	_show_stats()


func _build_controls() -> void:
	var controls := %Controls as Container
	controls.add_child(_label("Serve games (prototype)", &"HeadingLabel"))
	var games := HFlowContainer.new()
	var group := ButtonGroup.new()
	for mode: ServeMinigamePrototype.Mode in ServeMinigamePrototype.NAMES:
		var button := _button(ServeMinigamePrototype.NAMES[mode], _pick_game.bind(mode))
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = mode == ServeMinigamePrototype.mode
		games.add_child(button)
	controls.add_child(games)
	group.pressed.connect(_mark.bind(group).unbind(1))
	_mark(group)
	_hint = _label("", &"BodyTextLabel")
	controls.add_child(_hint)
	controls.add_child(_label("How often someone asks", &"SmallStrongLabel"))
	var paces := HBoxContainer.new()
	var pace_group := ButtonGroup.new()
	for pace: String in PACES:
		var button := _button("%s (%.1f s)" % [pace, PACES[pace]], _pick_pace.bind(pace))
		button.toggle_mode = true
		button.button_group = pace_group
		button.button_pressed = pace == START_PACE
		paces.add_child(button)
	controls.add_child(paces)
	pace_group.pressed.connect(_mark.bind(pace_group).unbind(1))
	_mark(pace_group)
	var droids := _button("Waiter droids", _toggle_droids)
	droids.toggle_mode = true
	droids.toggled.connect(_light.bind(droids))
	controls.add_child(droids)
	_stats = _label("", &"BodyTextLabel")
	controls.add_child(_stats)
	var row := HBoxContainer.new()
	row.add_child(_button("Clear the numbers", _clear))
	row.add_child(_button("Back to the menu", SceneFlow.go_to.bind(MAIN_MENU)))
	controls.add_child(row)


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(action)
	return button


# The picked button of group reads as the panel's primary button, the rest as quiet ones.
func _mark(group: ButtonGroup) -> void:
	for button: BaseButton in group.get_buttons():
		_light(button.button_pressed, button)


func _light(on: bool, button: BaseButton) -> void:
	button.theme_type_variation = &"SmallPrimaryButton" if on else &"SmallButton"


func _pick_game(mode: ServeMinigamePrototype.Mode) -> void:
	ServeMinigamePrototype.mode = mode
	_hint.text = ServeMinigamePrototype.HINTS[mode]
	_clear()


func _pick_pace(pace: String) -> void:
	_pace = PACES[pace]
	_until_ask = minf(_until_ask, _pace)


func _toggle_droids() -> void:
	var cabin := %Cabin as Cabin
	cabin.amenities = [] if not cabin.amenities.is_empty() else [Cabin.SERVING_ROBOTS]


func _clear() -> void:
	_waits.clear()


func _show_stats() -> void:
	var text := "Waiting now: %d\nServed: %d" % [_asked.size(), _waits.size()]
	if not _waits.is_empty():
		var total := 0.0
		for wait: float in _waits:
			total += wait
		text += (
			"\nAsked to served: %.1f s on average, %.1f s last"
			% [total / _waits.size(), _waits[-1]]
		)
	if _stats.text != text:
		_stats.text = text
