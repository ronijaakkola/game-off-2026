class_name Tutorial
extends Node
## The tutorial at the start of a new run, on the map zoomed in on [member home]
## ([MapZoom]): one ride from [member home] to [member destination] and back, a step at a
## time. It opens on The Boss's call ([TutorialCall]), and once the player closes The
## Boss's transmission, the steps start.
## A step shows a guide card that points at what it is about and goes once the player has
## done what it says: the bus, the passenger waiting at home, the On board panel they come
## into, setting a course to the destination, charging the drive, serving the snack the
## passenger asks for halfway, the stars they rate the ride, the fare and research point
## they pay, refuelling, home's lab badge and setting a course back home, charging again,
## the lab's Research button, and in the research screen its title, Fuel tank 1 to
## research, and its close button. Then The Boss calls again, and once the player
## answers, the HUD goes and it is over; the HUD comes back once the map has zoomed out.
## Most steps wait for the player to do something in the game; one that only tells them
## something has a Got it button. The snack and the stars pause the game, and the
## portraits keep moving. The cards are [TutorialCards].
## The HUD only shows what a step has brought in: the station panel comes in with the
## pick-up, the On board panel once the passenger boards, before their card slides into
## it, and the resource bar once their card has left it. The station's fuel button shows
## from the flight on, and its Research button and home's lab badge from the course home.
## The station's Board all button stays hidden throughout, and no other planet shows its
## lab badge. Until the pick-up, the screen takes no clicks but on the guide card.
## A course can be set only to where the step heads ([method allows_course]), the route
## can't change in flight ([method locks_route]), and the research screen can't be closed
## until the step says so. What else it changes about the game is [TutorialRules]'.
## Through it, only home and the destination have lines, with the one passenger at home,
## and nobody joins or leaves a line. The passenger asks for nothing but the snack. The
## debug panel's Skip tutorial finishes it at once.

## The tutorial is over, done or skipped. The lines run again.
signal finished

enum Step {
	CALL,
	BUS,
	BOARD,
	ON_BOARD,
	ROUTE,
	CHARGE,
	FLY,
	SERVE,
	RATING,
	MONEY,
	REFUEL,
	LAB_ROUTE,
	LAB,
	RESEARCH,
	UPGRADE,
	CLOSE,
	LAST_CALL,
	DONE,
}

## What the passenger asks for, halfway to the destination.
const SNACK := preload("res://game/passengers/needs/snack.tres")
## How many times longer the passenger's needs wait once on board, and again once the snack
## is served: long past the end of it, so nothing else comes up.
const NO_NEEDS := 1000.0
## Seconds after the stars have filled on the passenger's card before the game pauses on
## them.
const STARS_BEAT := 0.2
## Seconds after the passenger's card has left the On board panel, for its group to fold
## away, before the resource bar comes in.
const LEFT_BEAT := 0.3
## Seconds after the bus docks at home before the card on the Research button opens, once
## the station panel has slid in.
const LAB_DELAY := 0.6
## Seconds after the tank is full before home's lab badge pops in.
const BADGE_DELAY := 0.5
## Seconds after the badge is in before its card opens.
const BADGE_BEAT := 0.2
## Seconds after the research screen opens, once its sheet has grown in, before the card
## on its title opens.
const SCREEN_DELAY := ResearchScreen.OPEN_SECONDS + 0.15
## Seconds after the research screen closes before The Boss calls again.
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
## Where the fare and the research point show.
@export var resource_bar: ResourceBar
## Shows the passenger's trip once they are on board.
@export var trip_arc: TripArc
## Where the bus starts and the passenger waits, and where the lab is.
@export var home: Planet
## Where the passenger goes.
@export var destination: Planet
## Brings the HUD in as steps need it, after the call hid all but the bus bars.
@export var hud: HudLayout
## The camera, which holds still through the call.
@export var rig: CameraRig
## Zooms the map out once it is over, and says when the run proper starts.
@export var map_zoom: MapZoom
## Only home's shows, from the course home.
@export var lab_badges: LabBadges
## Where Fuel tank 1 is researched.
@export var research_lab: ResearchLab
## The research screen, which can't close until the last step in it.
@export var research_screen: ResearchScreen
## Points at what a step is about and says what to do.
@export var guide: GuideCard

## Who waits at each planet. The parent sets it before [method start].
var waiting: WaitingPassengers

var _step := Step.DONE
var _running := false
# The passenger the tutorial is about, once picked up, and their card.
var _passenger: Passenger
var _card: PassengerCard
# Where the bus is headed: the destination, then home.
var _goal: Planet
# Whether the station panel has come in, so the card on the passenger can show.
var _station_in := false
# Opens the steps' guide cards.
var _cards: TutorialCards
# How far the bus had to go as it left, and whether the passenger has asked for their
# snack.
var _leg := 0.0
var _asked := false
# The stars the passenger rated the ride, and where they show on their card.
var _rating := 0
var _stars: Control
# What it changes about the game while it runs.
var _rules: TutorialRules


func _ready() -> void:
	set_process(false)
	DebugPanel.add_button("Skip tutorial", _debug_skip_tutorial, self)


# Leaving mid-tutorial, as to the main menu: what outlives the scene goes back.
func _exit_tree() -> void:
	if _running:
		_rules.put_back_upgrade()


func _process(_delta: float) -> void:
	var on_route := _goal in bus.get_route_planets()
	# The trip shows from boarding until the bus leaves. Again every frame, since the
	# station panel hides it as its rows change.
	if _step in TRIP_STEPS and _goal == destination:
		trip_arc.show_passenger(_passenger)
	if _step in RIDE_STEPS and _goal == destination:
		_rules.hold_fare(_passenger)
	match _step:
		Step.BUS:
			guide.target_rect = _screen_rect(bus.global_position, FrameshiftBus.RADIUS)
		Step.BOARD:
			_guide_boarding()
			if not cabin.get_passengers().is_empty():
				_passenger = cabin.get_passengers()[0]
				_passenger.delay_requests(NO_NEEDS)
				_go_to(Step.ON_BOARD)
		Step.ROUTE:
			guide.target_rect = _screen_rect(
				destination.get_body_global_position(), destination.get_body_radius()
			)
			if on_route:
				_go_to(Step.CHARGE)
		Step.LAB_ROUTE:
			if on_route:
				_go_to(Step.CHARGE)
		Step.CHARGE:
			if bus.state == FrameshiftBus.State.FLYING:
				_leg = _distance_left()
				_rules.set_trip_burn(_goal)
				_go_to(Step.FLY)
			elif not on_route:
				_go_to(_route_step())
		Step.FLY:
			_fly()
		Step.SERVE:
			if not _passenger.request:
				_passenger.delay_requests(NO_NEEDS)
				_rules.pause(false)
				_go_to(Step.FLY)
		Step.REFUEL:
			var full := bus.get_fuel_tank().get_fraction() >= 1.0
			if full and bus.is_at_planet() and not cabin.is_stopping():
				_go_to(Step.LAB_ROUTE)


## Starts it with the call: only home and the destination have lines, with the one
## passenger at home.
func start() -> void:
	_running = true
	_goal = destination
	waiting.set_process(false)
	waiting.set_planets([home, destination])
	_add_passenger()
	rig.locked = true
	_cards = TutorialCards.new(guide)
	_rules = TutorialRules.new(self)
	_rules.apply()
	_rules.set_trip_burn(_goal)
	guide.acknowledged.connect(_on_guide_acknowledged)
	research_lab.get_research().researched.connect(_on_researched)
	research_screen.closed.connect(_on_research_closed)
	cabin.getting_off.connect(_on_getting_off)
	dock_panel.research_pressed.connect(_on_research_pressed)
	intro.ended.connect(_on_call_ended)
	_go_to(Step.CALL)
	intro.play(home, destination)


func is_running() -> bool:
	return _running


## Whether the player may add [param stop] to the course: only where a step heads, while it
## asks for the course.
func allows_course(stop: RouteStop) -> bool:
	if not _running:
		return true
	return _step in [Step.ROUTE, Step.LAB_ROUTE] and stop.planet == _goal


## Whether the route can't change: through a trip, so the bus flies on to where it is
## headed.
func locks_route() -> bool:
	return _running and _step in [Step.FLY, Step.SERVE]


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
	dock_panel.beckon_boarding = step == Step.BOARD
	_cards.close()
	match step:
		Step.BUS:
			guide.target_rect = _screen_rect(bus.global_position, FrameshiftBus.RADIUS)
			_open_card(null)
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
		Step.LAB_ROUTE:
			_bring_in_badge()
		Step.LAB:
			_open_lab()
		Step.RESEARCH:
			_open_research()
		Step.UPGRADE:
			var fuel_tank := _rules.get_fuel_tank()
			research_lab.researchable = [fuel_tank]
			_open_card(research_screen.get_button(fuel_tank))
		Step.LAST_CALL:
			_call_again()
		Step.CLOSE:
			research_lab.researchable = []
			research_screen.close_locked = false
			_open_card(research_screen.get_close_button())


# Opens this step's guide card on [param target], or on [member GuideCard.target_rect]
# when it is null. It returns once the card opens.
func _open_card(target: Control) -> void:
	var names := {
		"home": home.display_name,
		"destination": _goal.display_name,
		"stars": "%d star%s" % [_rating, "" if _rating == 1 else "s"],
	}
	await _cards.open(Step.keys()[_step], target, names)


# Got it: the card is read.
func _on_guide_acknowledged() -> void:
	match _step:
		Step.BUS:
			_go_to(Step.BOARD)
		Step.ON_BOARD:
			_go_to(Step.ROUTE)
		Step.RATING:
			_rules.pause(false)
			_go_to(Step.MONEY)
		Step.MONEY:
			resource_bar.breathe(PASSENGER_RACE, false)
			_go_to(Step.REFUEL)
		Step.RESEARCH:
			_go_to(Step.UPGRADE)


# In flight: halfway to the destination the passenger asks for their snack; docked at home,
# the lab's card comes; stopped short, the course is set again.
func _fly() -> void:
	if _goal == destination and not _asked and _distance_left() <= _leg * 0.5:
		_asked = true
		_passenger.ask_for(SNACK)
		_go_to(Step.SERVE)
	elif _goal == home and bus.is_at_planet() and bus.get_docked_planet() == home:
		_go_to(Step.LAB)
	elif _goal not in bus.get_route_planets() and _is_stranded():
		_go_to(_route_step())


# The step that sets the course to where the bus is headed.
func _route_step() -> Step:
	return Step.ROUTE if _goal == destination else Step.LAB_ROUTE


# The game pauses on the passenger's request, with the card beside their serve button.
func _open_serving() -> void:
	_rules.pause(true, true)
	# The card shows its serve button once it has seen the request.
	await get_tree().process_frame
	var card := passenger_panel.get_card(_passenger)
	if _step == Step.SERVE and card:
		_open_card(card.get_serve_button())


# The passenger gets off at the destination: their card shows the stars they rate the
# ride.
func _on_getting_off(passenger: Passenger) -> void:
	if not _running or passenger != _passenger:
		return
	_rating = roundi(passenger.get_rating())
	_card = passenger_panel.get_card(passenger)
	_stars = _card.get_rating_stars() if _card else null
	_go_to(Step.RATING)


# Once the stars have filled, the game pauses on them with a card beside them.
func _open_rating() -> void:
	var fill := _rating * PassengerCard.STAR_FILL_SECONDS
	var wait := PassengerCard.SWAP_STAGGER + PassengerCard.SWAP_SECONDS + fill + STARS_BEAT
	await get_tree().create_timer(wait).timeout
	if _step != Step.RATING or not _stars:
		return
	_rules.pause(true)
	_open_card(_stars)


# Once the passenger's card has left the On board panel, the resource bar comes in with
# the fare and the research point, then a card under it while they breathe.
func _bring_in_money() -> void:
	if is_instance_valid(_card) and _card.is_inside_tree():
		await _card.left
		await get_tree().create_timer(LEFT_BEAT).timeout
	if _step != Step.MONEY:
		return
	await hud.reveal([HudLayout.Part.RESOURCE_BAR])
	if _step == Step.MONEY:
		_open_card(resource_bar)
		resource_bar.breathe(PASSENGER_RACE, true)


# Docked at home: once the station panel has slid in with its Research button, the card
# points at it.
func _open_lab() -> void:
	dock_panel.research_hidden = false
	await get_tree().create_timer(LAB_DELAY).timeout
	if _step == Step.LAB:
		_open_card(dock_panel.get_research_button())


# The card on the fuel button opens, and only then can the player fuel.
func _open_refuel() -> void:
	await _open_card(dock_panel.get_fuel_button())
	if _step == Step.REFUEL:
		dock_panel.fuel_locked = false


# Research: the lab opens.
func _on_research_pressed(_at: Planet) -> void:
	if _step == Step.LAB:
		_go_to(Step.RESEARCH)


# After the tank is full, home's lab badge pops in, then a card beside it.
func _bring_in_badge() -> void:
	_goal = home
	await get_tree().create_timer(BADGE_DELAY).timeout
	if _step != Step.LAB_ROUTE:
		return
	# Back to the course after clearing it, the badge is already in.
	if not lab_badges.visible:
		lab_badges.show()
		await lab_badges.pop_in(home)
		await get_tree().create_timer(BADGE_BEAT).timeout
	if _step == Step.LAB_ROUTE:
		_open_card(lab_badges.get_badge(home))


# The research screen has opened, and can't close yet: once it has grown in, a card on its
# title, and nothing can be researched until it is read.
func _open_research() -> void:
	research_screen.close_locked = true
	await get_tree().create_timer(SCREEN_DELAY).timeout
	if _step == Step.RESEARCH:
		_open_card(research_screen.get_title())


# Fuel tank 1 is researched.
func _on_researched(upgrade: Upgrade) -> void:
	if _step == Step.UPGRADE and upgrade == _rules.get_fuel_tank():
		_go_to(Step.CLOSE)


# The research screen closed.
func _on_research_closed() -> void:
	if _step == Step.CLOSE:
		_go_to(Step.LAST_CALL)


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
		_open_card(passenger_panel)


# How far the bus is from where it is headed.
func _distance_left() -> float:
	return bus.global_position.distance_to(_goal.get_body_global_position())


# The square on screen around a ball of [param radius] at [param point].
func _screen_rect(point: Vector3, radius: float) -> Rect2:
	var camera := get_viewport().get_camera_3d()
	var centre := camera.unproject_position(point)
	var edge := camera.unproject_position(point + camera.global_basis.x * radius)
	var size := centre.distance_to(edge)
	return Rect2(centre - Vector2.ONE * size, Vector2.ONE * size * 2.0)


# The tutorial's passenger waits at home: always blue, so the research point they pay is
# always blue too.
func _add_passenger() -> void:
	waiting.deal_next(PASSENGER_RACE)
	waiting.add(home)
	# Decided now, so their row shows the fare they will pay.
	waiting.get_waiting(home)[0].fare = TutorialRules.FARE


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


# The lab closed: the screen takes no clicks and the camera holds still, and a moment later
# The Boss calls again.
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
	hud.cover()
	hud.hide_all()
	lab_badges.hide()
	# The camera stays locked: the zoom out holds it until the run starts.
	map_zoom.zoomed_out.connect(_on_zoomed_out, CONNECT_ONE_SHOT)
	_rules.lift()
	resource_bar.breathe(PASSENGER_RACE, false)
	_rules.pause(false)
	if _step in TRIP_STEPS:
		trip_arc.hide_trip()
	_step = Step.DONE
	dock_panel.beckon_boarding = false
	set_process(false)
	intro.cancel()
	_cards.close()
	waiting.set_process(true)
	finished.emit()


# The map has zoomed out and settled: the HUD comes back, and the player can play.
func _on_zoomed_out() -> void:
	hud.reveal_all()
	lab_badges.show()


# Skip tutorial: finishes it, and the map zooms out.
func _debug_skip_tutorial() -> void:
	skip()
