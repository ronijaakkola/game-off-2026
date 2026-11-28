extends Node
## Offers the requests feature hint, and holds requests back until it can: nobody on board
## asks for anything until the player has delivered [member deliveries] passengers after
## the tutorial, so the first rides are about the route and the fare alone. Then the first
## request that opens pauses the game with the hint beside its serve button, once the
## passenger has called out for it ([constant CALL_SECONDS]). A run that has
## taught it already, or shows no hints ([method FeatureHints.has_taught]), holds nothing
## back. The deliveries count from the scene starting, so a continued run counts again.

## How many times as long what is left of each held passenger's waits for their requests
## becomes while held: long past any ride, so their timers barely move, and they pick up
## about where they were once let go.
const HOLD_SCALE := 1000.0
## Seconds from the serve button showing to the hint, so the passenger's call-out, which
## the pause would cut off, is heard first. Under [constant Passenger.REQUEST_LEEWAY], so
## their happiness hasn't started to fall.
const CALL_SECONDS := 0.8

@export var hints: FeatureHints
@export var cabin: Cabin
## Where the serve buttons are.
@export var passenger_panel: PassengerPanel
## Nothing it does counts while it runs: its passenger asks for nothing anyway.
@export var tutorial: Tutorial
## How many passengers the player delivers after the tutorial before anyone asks for
## anything.
@export var deliveries := 2

var _delivered := 0
# Whoever on board it holds back, until it lets go.
var _held: Array[Passenger] = []
# Whether it has looked at who was on board as the scene started, as a continued run's.
var _started := false
# How long the serve button the hint would point at has shown.
var _shown_for := 0.0


func _ready() -> void:
	hints.set_debug_target(&"requests", _serve_button)
	cabin.boarded.connect(_hold)
	cabin.delivered.connect(_on_delivered)


func _process(delta: float) -> void:
	if not _started:
		_started = true
		for passenger: Passenger in cabin.get_passengers():
			_hold(passenger)
	if hints.has_taught(&"requests"):
		_let_go()
		set_process(false)
		return
	if _is_holding():
		return
	var button := _serve_button()
	_shown_for = _shown_for + delta if button else 0.0
	if _shown_for >= CALL_SECONDS and hints.offer(&"requests", button):
		set_process(false)


# Whether requests wait still: the hint hasn't been taught and too few have been delivered.
func _is_holding() -> bool:
	return _delivered < deliveries and not hints.has_taught(&"requests")


func _hold(passenger: Passenger) -> void:
	if tutorial.is_running() or not _is_holding() or passenger in _held:
		return
	passenger.delay_requests(HOLD_SCALE)
	_held.append(passenger)


func _on_delivered(_passenger: Passenger, _payout: int) -> void:
	if tutorial.is_running():
		return
	_delivered += 1
	if not _is_holding():
		_let_go()


# Whoever it held and is still on board waits for their requests as before.
func _let_go() -> void:
	var on_board := cabin.get_passengers()
	for passenger: Passenger in _held:
		if passenger in on_board:
			passenger.delay_requests(1.0 / HOLD_SCALE)
	_held.clear()


# The serve button of someone on board with a request open, once their card shows it.
func _serve_button() -> Control:
	for passenger: Passenger in cabin.get_passengers():
		var card := passenger_panel.get_card(passenger)
		if passenger.request and card and card.get_serve_button().is_visible_in_tree():
			return card.get_serve_button()
	return null
