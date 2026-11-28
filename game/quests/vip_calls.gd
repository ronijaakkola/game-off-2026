class_name VipCalls
extends Node
## Has VIPs call the bus ([Vip]). Now and then in the star system VIPs live in
## ([constant LEVEL]), someone waiting at a planet calls: an incoming transmission notice
## from a caller the player can't see yet ([constant UNKNOWN_NAME]), whose Answer opens
## their [VipTourQuest]'s transmission, with where to pick them up and the stops they want
## in order. Declining, or letting it ring out, costs nothing: they aren't a passenger yet.
## Accepted, they wait at their planet under a pick-up marker ([PickUpMarkers]), first in
## its line, taking one of its places ([member WaitingPassengers.reserved]), for a time set as
## the transmission opens and shown in it, which the marker's edge counts down. Not picked
## up by then, they give up and the tour fails. The [QuestGiver] tracks and pays the quest
## apart from a passenger's, so one of those can be under way at the same time; only one
## VIP calls or tours at a time. While a VIP's call rings or their transmission shows, no
## passenger calls.
## VIPs unlock in that system once the player has delivered [constant FIRST_DELIVERIES]
## passengers there ([signal unlocked]), and a save keeps how many they have.
## A VIP who waits is not in a save game: a continued run has no quest for them. One on
## board is saved with their quest as any caller is.

## VIPs started calling in the star system the bus works in.
signal unlocked

## The star system VIPs call in, counted from 0 in the order they open.
const LEVEL := 2
## How many passengers the player has delivered in that system before the first call, and
## the seconds into it at the least.
const FIRST_DELIVERIES := 6
const FIRST_SECONDS := 20.0
## Seconds from one call or tour ending to the next call: a random value between the two.
const CALL_MIN_SECONDS := 30.0
const CALL_MAX_SECONDS := 60.0
## Seconds before trying again when no call could be made.
const RETRY_SECONDS := 3.0
## Seconds a call rings before it goes unanswered.
const RING_SECONDS := 20.0
## How long they wait to be picked up, so the player can finish what they are doing first:
## the least, and on top the flight to them from where the bus is as the transmission
## opens, times the slack, up to the most.
const PICK_UP_SLACK := 2.0
const PICK_UP_MIN_SECONDS := 60.0
const PICK_UP_MAX_SECONDS := 90.0
## Seconds of their trip time for each stop of the tour before the last: their clock runs
## on while the bus is docked there.
const STOP_SECONDS := 8.0
## The chance a call is from one of [member custom_vips], until the player has accepted
## one in this star system.
const CUSTOM_CHANCE := 0.25
## How many stops a tour has.
const STOPS := 3
## Who the call notice says is calling, over their outline in the dark: the player sees
## who it is once they answer.
const UNKNOWN_NAME := "Someone very important"
## The line under their name on the pick-up marker.
const MARKER_LINE := "VIP waiting for a pick-up"

@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Tracks and pays an accepted tour, and keeps quiet while a VIP calls.
@export var quest_giver: QuestGiver
@export var pick_up_markers: PickUpMarkers
## The hand-written VIPs there are. A call is from one of them at random
## [constant CUSTOM_CHANCE] of the time, until the player has accepted one in this star
## system; [method call_soon] has a chosen one call whatever that says.
@export var custom_vips: Array[CustomVip] = []

var _planets: Array[Planet] = []
var _ledger: Ledger
var _waiting: WaitingPassengers
var _level := -1
# How many rides were rated when the bus started in this system.
var _rated_at_start := 0
var _rng := RandomNumberGenerator.new()
var _until_call := FIRST_SECONDS
# Whether the next call was asked for, so it comes whatever the system and the deliveries.
var _call_asked := false
# The hand-written VIP the call asked for is, or null for a rolled one.
var _custom: CustomVip
# Whether the player has accepted a hand-written VIP in this star system.
var _custom_met := false
var _unlocked := false
# The call ringing and the seconds it still rings, the quest it offers, then the quest on
# offer in the transmission panel, then the one accepted until it ends.
var _call: Notice
var _ring_left := 0.0
var _offer: VipTourQuest
var _quest: VipTourQuest
# Whether passengers called before a VIP's call silenced them.
var _quests_were_enabled := true


func _ready() -> void:
	if cabin:
		cabin.boarded.connect(_on_boarded)
	if quest_giver:
		quest_giver.changed.connect(_on_quests_changed)


func _process(delta: float) -> void:
	if _call:
		_ring_left -= delta
		if _ring_left <= 0.0:
			_hang_up()
		return
	if _offer:
		# Closed unanswered, as when something else takes the panel away: the offer is off.
		if not transmission_panel.is_open():
			_hang_up()
		return
	if _quest:
		_wait_for_pick_up(delta)
		return
	if not _waiting or not (_call_asked or _level == LEVEL):
		return
	_check_unlocked()
	_count_down(delta)
	if _until_call > 0.0 or not _is_time_to_call():
		return
	var drawn := _draw_custom() if not _custom else null
	if drawn:
		_custom = drawn
	_offer = _plan()
	if not _offer:
		if drawn:
			_custom = null
		_until_call = RETRY_SECONDS
		return
	_quests_were_enabled = quest_giver.enabled
	quest_giver.enabled = false
	_ring_left = RING_SECONDS
	var caller := Transmission.from_passenger(_offer.passenger)
	caller.unknown_name = UNKNOWN_NAME
	_call = notices.announce_transmission(caller, false, true)
	_call.action_pressed.connect(_on_call_answered)
	_call.declined.connect(_hang_up)


## Tells it the run's [param planets], which VIPs wait at and tour, the [param ledger]
## that counts deliveries, and [param waiting], which prices and times their trips and
## holds their place at a planet. [param level] is the star system the bus works in,
## counted from 0 in the order they open: VIPs call only in [constant LEVEL].
func start(planets: Array[Planet], ledger: Ledger, waiting: WaitingPassengers, level := 0) -> void:
	_planets = planets
	_ledger = ledger
	_waiting = waiting
	_level = level
	_rated_at_start = ledger.get_rating_count() if ledger else 0
	_until_call = FIRST_SECONDS
	_custom_met = false
	_unlocked = false


## Whether VIPs have started calling in the star system the bus works in.
func is_unlocked() -> bool:
	return _unlocked


## How many passengers have been delivered in this star system, for a save game.
func to_save() -> Dictionary:
	return {"delivered": _get_delivered()}


## Puts back what [method to_save] gave, after [method start]: VIPs unlock at once if
## enough passengers were delivered.
func load_save(saved: Dictionary) -> void:
	if _ledger:
		_rated_at_start = _ledger.get_rating_count() - int(saved.get("delivered", 0))
	_check_unlocked()


## Makes the dice repeatable.
func seed_dice(value: int) -> void:
	_rng.seed = value


## Has a VIP call as soon as one can, in any star system and however few passengers have
## been delivered: [param custom], or without one a rolled VIP.
func call_soon(custom: CustomVip = null) -> void:
	_until_call = 0.0
	_call_asked = true
	_custom = custom


# Whether a call could come now: nobody else is on the line, no stop is under way, and VIPs
# have unlocked here.
func _is_time_to_call() -> bool:
	if not quest_giver.is_line_free() or cabin.is_stopping():
		return false
	return _call_asked or _unlocked


# The wait for the next call runs, but holds while a tour put back from a save is under way,
# so the next call comes no sooner after it than after any other.
func _count_down(delta: float) -> void:
	if quest_giver.get_tour():
		_until_call = maxf(_until_call, CALL_MIN_SECONDS)
	else:
		_until_call -= delta


func _get_delivered() -> int:
	return _ledger.get_rating_count() - _rated_at_start if _ledger else 0


# VIPs unlock once, in the star system they call in, as enough passengers are delivered.
func _check_unlocked() -> void:
	if _unlocked or _level != LEVEL or _get_delivered() < FIRST_DELIVERIES:
		return
	_unlocked = true
	unlocked.emit()


# A VIP waiting at a planet the bus isn't docked at, with a tour of [constant STOPS] stops,
# none where they wait or the one before it, and the quest that offers it. Null with too
# few planets. Their trip is every leg flown straight from where the planets are now, with
# [constant STOP_SECONDS] for each stop on the way, and their fare the whole distance's.
func _plan() -> VipTourQuest:
	var open: Array[Planet] = []
	for planet: Planet in _planets:
		if not planet.abandoned:
			open.append(planet)
	var pick_up := _pick(open, bus.get_docked_planet())
	if open.size() < 3 or not pick_up:
		return null
	open.erase(pick_up)
	var stops: Array[Planet] = []
	var last := pick_up
	var distance := 0.0
	var seconds := 0.0
	for i: int in STOPS:
		var stop := _pick(open, last)
		var leg := last.get_body_global_position().distance_to(stop.get_body_global_position())
		distance += leg
		seconds += _waiting.get_trip_seconds(leg) + (STOP_SECONDS if i > 0 else 0.0)
		stops.append(stop)
		last = stop
	var fare := distance * _waiting.get_fare_per_unit()
	var vip := Passenger.new(Vip.TYPE, stops[0], seconds, fare, _rng)
	vip.origin = pick_up
	vip.tour = Tour.new(stops)
	Vip.dress(vip)
	var quest := VipTourQuest.new()
	quest.level = _level
	if _custom:
		var rolled := vip.name.split(" ", true, 1)
		var title := _custom.title if _custom.title else rolled[0]
		vip.name = "%s %s" % [title, _custom.name if _custom.name else rolled[1]]
		quest.custom_text = _custom.text
	return quest if quest.plan(vip, bus, _planets, _waiting, _rng) else null


# One of [member custom_vips] at random, [constant CUSTOM_CHANCE] of the time, while the
# player has accepted none in this star system. Null otherwise.
func _draw_custom() -> CustomVip:
	if _custom_met or custom_vips.is_empty() or _rng.randf() >= CUSTOM_CHANCE:
		return null
	return custom_vips[_rng.randi_range(0, custom_vips.size() - 1)]


# One of [param planets] at random that isn't [param other], or null with none.
func _pick(planets: Array[Planet], other: Planet) -> Planet:
	var able := planets.filter(func(planet: Planet) -> bool: return planet != other)
	return able[_rng.randi_range(0, able.size() - 1)] if not able.is_empty() else null


func _on_call_answered() -> void:
	if not _call:
		return
	_call = null
	var flight := Quest.get_chase_distance(bus, _offer.passenger.origin)
	_offer.pick_up_seconds = minf(
		PICK_UP_MIN_SECONDS + _waiting.get_trip_seconds(flight) * PICK_UP_SLACK, PICK_UP_MAX_SECONDS
	)
	transmission_panel.answered.connect(_on_answered, CONNECT_ONE_SHOT)
	transmission_panel.open(_offer.get_transmission())


func _on_answered(accepted: bool) -> void:
	var quest := _offer
	var custom := _custom
	_end_call()
	if not accepted or not quest:
		return
	_custom_met = _custom_met or custom != null
	quest.accept()
	_quest = quest
	quest.goal.changed.connect(_on_goal_changed)
	var vip := quest.passenger
	_waiting.reserved = vip
	if pick_up_markers:
		pick_up_markers.show_marker(vip.origin, vip, MARKER_LINE)
	quest_giver.take_on(quest)


# The call goes, declined or unanswered, or its transmission closed with no answer.
func _hang_up() -> void:
	if _call:
		_call.dismiss()
	if transmission_panel.answered.is_connected(_on_answered):
		transmission_panel.answered.disconnect(_on_answered)
	_end_call()


# Passengers may call again, and no VIP does for a while.
func _end_call() -> void:
	_call = null
	_offer = null
	_call_asked = false
	_custom = null
	quest_giver.enabled = _quests_were_enabled
	_until_call = _rng.randf_range(CALL_MIN_SECONDS, CALL_MAX_SECONDS)


# Their wait runs, and the marker's edge shows how much of it is left.
func _wait_for_pick_up(delta: float) -> void:
	var goal := _quest.goal as VipTourGoal
	if goal.boarded:
		return
	if pick_up_markers:
		var left := goal.seconds_left / _quest.pick_up_seconds
		pick_up_markers.set_time_left(_quest.passenger.origin, left)
	# Last: a wait that runs out ends the quest.
	goal.wait(delta)


func _on_boarded(passenger: Passenger) -> void:
	if not _quest or passenger != _quest.passenger:
		return
	(_quest.goal as VipTourGoal).board()
	if pick_up_markers:
		pick_up_markers.remove_marker(passenger.origin)


# The flag on their portrait says the step the player is on.
func _on_goal_changed() -> void:
	if _quest and _quest.goal.is_active():
		_quest.passenger.quest_line = _quest.goal.get_text()


# The tour ended: whoever still waited is gone.
func _on_quests_changed() -> void:
	if not _quest or quest_giver.get_tour() == _quest:
		return
	var vip := _quest.passenger
	_quest.goal.changed.disconnect(_on_goal_changed)
	if not (_quest.goal as VipTourGoal).boarded:
		_waiting.reserved = null
		if pick_up_markers:
			pick_up_markers.remove_marker(vip.origin)
	_quest = null
	_until_call = _rng.randf_range(CALL_MIN_SECONDS, CALL_MAX_SECONDS)
