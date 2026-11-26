class_name Tutorial
extends Node
## The tutorial at the start of a new run, on the map zoomed in on [member home]
## ([MapZoom]): one ride from [member home] to [member destination], a step at a time. It
## opens on The Boss's call ([TutorialCall]), and once the player closes The Boss's
## transmission, the steps start.
## A step shows a guide card that points at what it is about and goes once the player has done what
## it says: the bus, trying the camera, the passenger waiting at home, their card in the On
## board panel they come into with its happiness bar, setting a course to the destination,
## charging the drive, serving the snack the passenger asks for halfway, the stars they rate
## the ride, the fare they pay, refuelling, and the way home by way of a capsule of credits
## adrift in space ([WayHome]), with a word at home on chaining stops. Then The Boss calls
## again, and once the player answers, the HUD goes and it is over; once the map has zoomed
## out, The Boss's first-shift call brings the HUD back ([FirstShiftCall]). Research comes
## later, with the mechanic's first call ([MechanicCall], [ResearchGuide]).
## Most steps wait for the player to do something in the game; one that only tells them
## something has a Got it button. The snack and the stars pause the game, and the
## portraits keep moving. The cards are [TutorialCards].
## The HUD only shows what a step has brought in: the station panel comes in with the
## pick-up, the On board panel once the passenger boards, before their card slides into
## it, and the resource bar once their card has left it. The station's fuel button shows
## from the flight on. The station's Board all and Research buttons stay hidden throughout,
## and so do the lab badges. Until the pick-up, the screen takes no clicks but on the guide
## card; trying the camera, it takes clicks and the camera is the player's from then on.
## A course can be set only to the destination, while a step asks for it
## ([method fit_course]), and the route can't change in flight
## ([member FrameshiftBus.route_locked]). What else it changes about the game is
## [TutorialRules]'.
## Through it, only home and the destination have lines, with the one passenger at home,
## and nobody joins or leaves a line. The passenger asks for nothing but the snack. The
## debug panel's Skip tutorial, on its Progress card, finishes it at once.

## The tutorial is over, done or skipped. The lines run again.
signal finished

enum Step {
	CALL,
	BUS,
	LOOK,
	BOARD,
	ON_BOARD,
	ROUTE,
	CHARGE,
	FLY,
	SERVE,
	RATING,
	MONEY,
	REFUEL,
	HOME,
	CHAIN,
	LAST_CALL,
	DONE,
}

## Seconds after the passenger's card has left the On board panel, for its group to fold
## away, before the resource bar comes in.
const LEFT_BEAT := 0.3
## Seconds after the player has tried the camera before its card goes: a beat to see it
## move.
const LOOK_BEAT := 0.8
## Seconds after the tank is full before The Boss calls again.
const LAST_CALL_DELAY := 1.0
## The race of the tutorial's passenger.
const PASSENGER_RACE := Race.Type.BLUE
## Seconds after the On board panel is in and the passenger's card starts sliding in, before
## the card on the panel opens.
const ON_BOARD_DELAY := PassengerCard.ENTER_SECONDS + 0.15
## The steps through which the passenger's trip shows, on the way to the destination.
const TRIP_STEPS: Array[Step] = [Step.ON_BOARD, Step.ROUTE, Step.CHARGE]
## The steps in which the passenger rides to the destination, paying what they should.
const RIDE_STEPS: Array[Step] = [Step.ON_BOARD, Step.ROUTE, Step.CHARGE, Step.FLY, Step.SERVE]

@export var bus: FrameshiftBus
@export var cabin: Cabin
## The calls it opens and closes on.
@export var intro: TutorialCall
## Where the station panel calls for the pick-up.
@export var dock_panel: DockPanel
## Where the passenger comes in once on board.
@export var passenger_panel: PassengerPanel
## Renders the passengers' portraits, which keep moving while it pauses the game.
@export var portrait_studio: PortraitStudio
## Holds the Frameshift key.
@export var bus_bars: BusStatusPanel
## Where the fare shows.
@export var resource_bar: ResourceBar
## Shows the passenger's trip once they are on board.
@export var trip_arc: TripArc
## Where the bus starts and the passenger waits.
@export var home: Planet
## Where the passenger goes.
@export var destination: Planet
## Brings the HUD in as steps need it, after the call hid all but the bus bars.
@export var hud: HudLayout
## The camera, which holds still through the call.
@export var rig: CameraRig
## Where the capsule on the way home drifts ([WayHome]).
@export var capsules: CapsuleField
## Hidden throughout.
@export var lab_badges: LabBadges
## Offers to skip it while it runs.
@export var pause_menu: PauseMenu
## Points at what a step is about and says what to do.
@export var guide: GuideCard

## Who waits at each planet. The parent sets it before [method start].
var waiting: WaitingPassengers

var _step := Step.DONE
var _running := false
# The debug panel's Skip tutorial, null with the panel off.
var _skip_button: Button
# The passenger the tutorial is about, on their ride, and their card once they get off.
var _ride: TutorialRide
var _card: PassengerCard
# Where the bus is headed: the destination.
var _goal: Planet
# Whether the station panel has come in, so the card on the passenger can show.
var _station_in := false
# Opens the steps' guide cards.
var _cards: TutorialCards
# Where the stars the passenger rated the ride show on their card.
var _stars: Control
# The route home through a waypoint, once the step asks for it.
var _way_home: WayHome
# What it changes about the game while it runs.
var _rules: TutorialRules
# Whether the player has panned and zoomed the camera since its card opened, once it has
# opened.
var _camera: CameraWatch


func _ready() -> void:
	set_process(false)
	var group := Progression.DEBUG_GROUP
	_skip_button = DebugPanel.add_button("Skip tutorial", _debug_skip_tutorial, self, group)
	_show_skippable()


func _process(_delta: float) -> void:
	var on_route := _goal in bus.get_route_planets()
	# The trip shows from boarding until the bus leaves. Again every frame, since the
	# station panel hides it as its rows change.
	if _step in TRIP_STEPS and _goal == destination:
		trip_arc.show_passenger(_ride.passenger)
	if _step in RIDE_STEPS and _goal == destination:
		_rules.hold_fare(_ride.passenger)
	match _step:
		Step.BUS, Step.LOOK:
			guide.target_rect = _screen_rect(bus.global_position, FrameshiftBus.RADIUS)
			if _camera and _camera.is_tried():
				_camera = null
				_leave_look()
		Step.BOARD:
			_guide_boarding()
			if not cabin.get_passengers().is_empty():
				_ride.board(cabin.get_passengers()[0])
				_go_to(Step.ON_BOARD)
		Step.ROUTE:
			guide.target_rect = _screen_rect(
				destination.get_body_global_position(), destination.get_body_radius()
			)
			if on_route:
				_go_to(Step.CHARGE)
		Step.CHARGE:
			if bus.state == FrameshiftBus.State.FLYING:
				_ride.leave(_distance_left())
				_rules.set_trip_burn(_goal)
				_go_to(Step.FLY)
			elif not on_route:
				_go_to(Step.ROUTE)
		Step.FLY:
			_fly()
		Step.SERVE:
			if _ride.is_served():
				_rules.pause(false)
				_go_to(Step.FLY)
		Step.REFUEL:
			var full := bus.get_fuel_tank().get_fraction() >= 1.0
			if full and bus.is_at_planet() and not cabin.is_stopping():
				_go_to(Step.HOME)
		Step.HOME:
			_way_home.update()
			var card := _way_home.get_card()
			if _way_home.is_home():
				_go_to(Step.CHAIN)
			elif not _cards.is_open_for(card):
				if card.is_empty():
					_cards.close()
				else:
					_open_card(null, card)


## Starts it with the call: only home and the destination have lines, with the one
## passenger at home.
func start() -> void:
	_running = true
	_show_skippable()
	_goal = destination
	rig.locked = true
	_cards = TutorialCards.new(guide)
	_ride = TutorialRide.new()
	_rules = TutorialRules.new(self)
	_rules.apply()
	_rules.set_trip_burn(_goal)
	guide.acknowledged.connect(_on_guide_acknowledged)
	pause_menu.offers_skip_tutorial = true
	pause_menu.skip_tutorial_pressed.connect(skip)
	cabin.getting_off.connect(_on_getting_off)
	intro.ended.connect(_on_call_ended)
	_go_to(Step.CALL)
	intro.play(home, destination)


func is_running() -> bool:
	return _running


## The stop to add for the player's click on [param stop], or null when they may not: only
## where the step heads, while it asks for the course, and on the way home only the route
## it asks for, a waypoint snapped to the capsule's spot. Its courses go exactly where it asks,
## so a held right button doesn't steer them.
func fit_course(stop: RouteStop) -> RouteStop:
	if not _running:
		return stop
	if _step == Step.HOME:
		return _way_home.fit(stop)
	return stop if _step == Step.ROUTE and stop.planet == _goal else null


## Finishes it now, wherever it got to. Does nothing unless it is running.
func skip() -> void:
	if _running:
		_finish()


func _go_to(step: Step) -> void:
	if step == _step:
		return
	if _step in TRIP_STEPS and step not in TRIP_STEPS:
		trip_arc.hide_trip()
	_step = step
	bus.route_locked = step in [Step.FLY, Step.SERVE]
	dock_panel.beckon_boarding = step == Step.BOARD
	_cards.close()
	match step:
		Step.BUS:
			guide.target_rect = _screen_rect(bus.global_position, FrameshiftBus.RADIUS)
			_open_card(null)
		Step.LOOK:
			_open_look()
		Step.BOARD:
			_bring_in_station()
		Step.ON_BOARD:
			_bring_in_on_board()
		Step.ROUTE:
			guide.target_rect = _screen_rect(
				destination.get_body_global_position(), destination.get_body_radius()
			)
			_open_card(null)
		Step.CHARGE:
			_open_card(bus_bars.get_frameshift_key())
		Step.FLY:
			dock_panel.fuel_hidden = false
		Step.SERVE:
			_open_serving()
		Step.RATING:
			_open_rating()
		Step.MONEY:
			_bring_in_money()
		Step.REFUEL:
			_open_refuel()
		Step.HOME:
			_way_home = WayHome.new(self, _rules)
		Step.CHAIN:
			_open_card(bus_bars.get_route_bar())
		Step.LAST_CALL:
			_call_again()


# Opens this step's guide card, or [param card] when given, on [param target], or on
# [member GuideCard.target_rect] when it is null. It returns once the card opens.
func _open_card(target: Control, card := "") -> void:
	var names := {
		"home": home.display_name,
		"destination": _goal.display_name,
		"stars": _ride.describe_rating(),
		"queue_key": QueueKey.get_icons(),
	}
	await _cards.open(card if card else Step.keys()[_step], target, names)


# Got it: the card is read.
func _on_guide_acknowledged() -> void:
	match _step:
		Step.BUS:
			_go_to(Step.LOOK)
		Step.ON_BOARD:
			_go_to(Step.ROUTE)
		Step.RATING:
			_rules.pause(false)
			_go_to(Step.MONEY)
		Step.MONEY:
			resource_bar.breathe(false)
			_go_to(Step.REFUEL)
		Step.CHAIN:
			_go_to(Step.LAST_CALL)


# In flight: halfway to the destination the passenger asks for their snack; stopped short,
# the course is set again.
func _fly() -> void:
	if _ride.asks_for_snack(_distance_left()):
		_go_to(Step.SERVE)
	elif _goal not in bus.get_route_planets() and _is_stranded():
		_go_to(Step.ROUTE)


# The game pauses on the passenger's request, with the card beside their serve button.
func _open_serving() -> void:
	_rules.pause(true, true)
	# The card shows its serve button once it has seen the request.
	await get_tree().process_frame
	var card := passenger_panel.get_card(_ride.passenger)
	if _step == Step.SERVE and card:
		_open_card(card.get_serve_button())


# The passenger gets off at the destination: their card shows the stars they rate the
# ride.
func _on_getting_off(passenger: Passenger) -> void:
	if not _running or passenger != _ride.passenger:
		return
	_ride.get_off()
	_card = passenger_panel.get_card(passenger)
	_stars = _card.get_rating_stars() if _card else null
	_go_to(Step.RATING)


# Once the stars have filled, the game pauses on them with a card beside them.
func _open_rating() -> void:
	await get_tree().create_timer(_ride.get_stars_seconds()).timeout
	if _step != Step.RATING or not _stars:
		return
	_rules.pause(true)
	_open_card(_stars)


# Once the passenger's card has left the On board panel, the resource bar comes in with
# the fare, then a card under it while the credits breathe.
func _bring_in_money() -> void:
	if is_instance_valid(_card) and _card.is_inside_tree():
		await _card.left
		await get_tree().create_timer(LEFT_BEAT).timeout
	if _step != Step.MONEY:
		return
	await hud.reveal([HudLayout.Part.RESOURCE_BAR])
	if _step == Step.MONEY:
		_open_card(resource_bar)
		resource_bar.breathe(true)


# The card on the fuel button opens, and only then can the player fuel.
func _open_refuel() -> void:
	await _open_card(dock_panel.get_fuel_row())
	if _step == Step.REFUEL:
		dock_panel.fuel_locked = false


# The screen takes clicks and the camera is the player's, and the card on the camera
# opens beside the bus; the camera counts as tried only from then on.
func _open_look() -> void:
	hud.uncover()
	rig.locked = false
	await _open_card(null)
	if _step == Step.LOOK:
		_camera = CameraWatch.new(rig)


# A beat after the player tried the camera, so they see it move, its card goes.
func _leave_look() -> void:
	await get_tree().create_timer(LOOK_BEAT).timeout
	if _step == Step.LOOK:
		_go_to(Step.BOARD)


# The screen takes clicks and the camera is the player's, and the station panel comes in.
func _bring_in_station() -> void:
	hud.uncover()
	rig.locked = false
	await hud.reveal([HudLayout.Part.STATION])
	_station_in = true


# The On board panel comes in, then the passenger's card slides into it, then the guide
# card opens beside it.
func _bring_in_on_board() -> void:
	await hud.reveal([HudLayout.Part.ON_BOARD])
	passenger_panel.arrivals_held = false
	await get_tree().create_timer(ON_BOARD_DELAY).timeout
	if _step == Step.ON_BOARD:
		var card := passenger_panel.get_card(_ride.passenger)
		_open_card(card if card else passenger_panel)


# How far the bus is from where it is headed.
func _distance_left() -> float:
	return bus.global_position.distance_to(_goal.get_body_global_position())


func _screen_rect(point: Vector3, radius: float) -> Rect2:
	return ScreenPick.square_around(get_viewport().get_camera_3d(), point, radius)


# The guide card points at the row of the passenger waiting at home, once the station
# panel is in and the row shows.
func _guide_boarding() -> void:
	if not _station_in:
		return
	var line := waiting.get_waiting(home)
	var row := dock_panel.get_row(line[0]) if not line.is_empty() else null
	if not row:
		return
	if not _cards.is_open_for("BOARD"):
		_open_card(row)


# The Boss's transmission closed: the ride starts.
func _on_call_ended() -> void:
	if _step == Step.CALL:
		set_process(true)
		_go_to(Step.BUS)
	elif _step == Step.LAST_CALL:
		await hud.hide_all()
		_finish()


# The tank is full: the screen takes no clicks and the camera holds still, and a moment
# later The Boss calls again.
func _call_again() -> void:
	hud.cover()
	rig.locked = true
	await get_tree().create_timer(LAST_CALL_DELAY).timeout
	if _step == Step.LAST_CALL:
		intro.ring(TutorialCall.LAST_CALLER, TutorialCall.LAST_TEXT, TutorialCall.LAST_ANSWERS)


# Whether the bus has stopped short of where it is headed: at rest in space, or docked at
# another planet, so it needs a course again.
func _is_stranded() -> bool:
	if bus.state == FrameshiftBus.State.HOLDING:
		return true
	return bus.is_at_planet() and bus.get_docked_planet() != _goal


func _finish() -> void:
	# Skipped while the last call's answer takes the HUD out, it has finished already.
	if not _running:
		return
	_running = false
	_show_skippable()
	hud.cover()
	_empty_home_line()
	lab_badges.hide()
	# The camera stays locked: the zoom out holds it until the run starts.
	_rules.lift()
	pause_menu.offers_skip_tutorial = false
	resource_bar.breathe(false)
	_rules.pause(false)
	if _step in TRIP_STEPS:
		trip_arc.hide_trip()
	_step = Step.DONE
	bus.route_locked = false
	dock_panel.beckon_boarding = false
	set_process(false)
	intro.cancel()
	_cards.close()
	finished.emit()


# Once the HUD has gone, the line at home empties where nobody sees it, so a passenger
# still waiting there when it is skipped doesn't leave in view as the run starts.
func _empty_home_line() -> void:
	await hud.hide_all()
	for passenger: Passenger in waiting.get_waiting(home):
		waiting.take(home, passenger)


# Skip tutorial: finishes it, and the map zooms out.
func _debug_skip_tutorial() -> void:
	skip()


# Skip tutorial is grey unless the tutorial runs, as there is nothing to skip.
func _show_skippable() -> void:
	if _skip_button:
		_skip_button.disabled = not _running
