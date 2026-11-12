class_name Tutorial
extends Node
## The tutorial at the start of a new run, on the map zoomed in on [member home]
## ([MapZoom]): one ride from [member home] to [member destination], a step at a time. Each
## step is a tutorial notice that goes once the player has done what it says: pick up the
## passenger waiting at home, set a course to the destination, charge the drive, serve what
## the passenger asks for on the way, and refuel once they are off. Then
## [signal finished]. Every notice has a Skip button, which finishes it at once, as does
## the debug panel's Skip tutorial.
## Until the passenger is picked up, the station panel calls for the pick-up and no course
## can be set ([method allows_course]), so the bus can't leave without them. Once they are
## on board, their trip shows as an arc to the destination until the bus leaves.
## Through it, only home and the destination have lines, with the one passenger at home,
## and nobody joins or leaves a line. The passenger asks for something soon after the bus
## leaves, so the short ride shows a request.

## The tutorial is over, done or skipped. The lines run again.
signal finished

enum Step { BOARD, ROUTE, CHARGE, FLY, SERVE, REFUEL, DONE }

const SKIP := "Skip tutorial"
## Seconds into the ride before the passenger asks for something.
const ASK_AFTER := 3.0
## What each step's notice says, with the planets' names for {home} and {destination}. A
## step without one shows none.
const TEXTS: Dictionary[Step, String] = {
	Step.BOARD: "Press Board to pick up the passenger waiting at {home}.",
	Step.ROUTE: "Right-click {destination} to set a course there.",
	Step.CHARGE: "Hold the Frameshift key to charge the drive and leave.",
	Step.SERVE: "Your passenger wants something. Hold the button on their card to serve it.",
	Step.REFUEL: "They paid by how happy they were. Hold the fuel button to refuel.",
}

@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack
## Where the station panel calls for the pick-up.
@export var dock_panel: DockPanel
## Shows the passenger's trip once they are on board.
@export var trip_arc: TripArc
## Where the bus starts and the passenger waits.
@export var home: Planet
## Where the passenger goes.
@export var destination: Planet

## Who waits at each planet. The parent sets it before [method start].
var waiting: WaitingPassengers

var _step := Step.DONE
var _running := false
var _notice: Notice
# The passenger the tutorial is about, once picked up.
var _passenger: Passenger


func _ready() -> void:
	set_process(false)
	DebugPanel.add_button("Skip tutorial", _debug_skip_tutorial, self)


func _process(_delta: float) -> void:
	var on_route := destination in bus.get_route_planets()
	var riding := _passenger != null and _passenger in cabin.get_passengers()
	# Kicked before the bus left: someone new waits at home to start over with.
	if _step in [Step.ROUTE, Step.CHARGE] and not riding:
		_passenger = null
		waiting.add(home)
		_go_to(Step.BOARD)
	# The trip shows from boarding until the bus leaves. Again every frame, since the
	# station panel hides it as its rows change.
	if _step in [Step.ROUTE, Step.CHARGE]:
		trip_arc.show_passenger(_passenger)
	match _step:
		Step.BOARD:
			if not cabin.get_passengers().is_empty():
				_passenger = cabin.get_passengers()[0]
				_go_to(Step.CHARGE if on_route else Step.ROUTE)
		Step.ROUTE:
			if on_route:
				_go_to(Step.CHARGE)
		Step.CHARGE:
			if bus.state == FrameshiftBus.State.FLYING:
				_passenger.ask_within(ASK_AFTER)
				_go_to(Step.FLY)
			elif not on_route:
				_go_to(Step.ROUTE)
		Step.FLY:
			if not riding:
				_go_to(Step.REFUEL)
			elif _passenger.request:
				_go_to(Step.SERVE)
			elif not on_route and _is_stranded():
				_go_to(Step.ROUTE)
		Step.SERVE:
			if not riding:
				_go_to(Step.REFUEL)
			elif not _passenger.request:
				_go_to(Step.FLY)
		Step.REFUEL:
			var full := bus.get_fuel_tank().get_fraction() >= 1.0
			if full and bus.is_at_planet() and not cabin.is_stopping():
				_finish()


## Starts it: only home and the destination have lines, with the one passenger at home.
func start() -> void:
	_running = true
	waiting.set_process(false)
	waiting.set_planets([home, destination])
	waiting.add(home)
	set_process(true)
	_go_to(Step.BOARD)


func is_running() -> bool:
	return _running


## Whether the player may set a course: not until the passenger is picked up.
func allows_course() -> bool:
	return not _running or _step != Step.BOARD


## Finishes it now, wherever it got to. Does nothing unless it is running.
func skip() -> void:
	if _running:
		_finish()


func _go_to(step: Step) -> void:
	if step == _step:
		return
	if _step in [Step.ROUTE, Step.CHARGE] and step not in [Step.ROUTE, Step.CHARGE]:
		trip_arc.hide_trip()
	_step = step
	dock_panel.beckon_boarding = step == Step.BOARD
	_dismiss_notice()
	var text: String = TEXTS.get(step, "")
	if text.is_empty():
		return
	text = text.format({"home": home.display_name, "destination": destination.display_name})
	_notice = notices.push(text, Notice.Kind.TUTORIAL, false, 0.0, SKIP)
	_notice.action_pressed.connect(skip)


# Whether the bus has stopped short of the destination: at rest in space, or docked at
# another planet, so the passenger needs a course again.
func _is_stranded() -> bool:
	if bus.state == FrameshiftBus.State.HOLDING:
		return true
	return bus.is_at_planet() and bus.get_docked_planet() != destination


func _finish() -> void:
	_running = false
	if _step in [Step.ROUTE, Step.CHARGE]:
		trip_arc.hide_trip()
	_step = Step.DONE
	dock_panel.beckon_boarding = false
	set_process(false)
	_dismiss_notice()
	waiting.set_process(true)
	finished.emit()


func _dismiss_notice() -> void:
	if _notice:
		_notice.dismiss()
		_notice = null


# Skip tutorial: finishes it, and the map zooms out.
func _debug_skip_tutorial() -> void:
	skip()
