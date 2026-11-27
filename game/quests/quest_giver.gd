class_name QuestGiver
extends Node
## Gives the player quests. Every so often while the bus flies, once the player has
## delivered [constant FIRST_CALL_DELIVERIES] passengers, a passenger on board calls:
## an incoming transmission notice, whose Answer opens their [Quest]'s transmission. They
## ask for whatever [QuestPicks] says suits them. Of those who can call, a returning
## passenger is likelier to be the one. One call or quest at a time: nobody calls while a
## quest is under way, and the wait until the next call starts only once it has ended. A
## VIP's tour ([VipCalls]) is tracked apart from that one, so a passenger's quest and a tour
## can be under way at once.
## A passenger picked up from a capsule adrift has their [RescueQuest]'s transmission open
## by itself, with no notice, [constant RESCUE_SECONDS] after ([method rescue]). They board
## only when the player accepts; declined, they stay adrift, at no cost.
## Accepting makes the quest's change, tracks its goal in [member quests] and flags the
## passenger. A completed quest pays its reward and lifts the passenger by
## [member done_happiness] for the rest of their ride; a failed one costs the passenger
## [constant FAIL_SHOCK] if they still ride, so nothing more when a kick failed it.
## Declining costs them [constant DECLINE_SHOCK], in the transmission or with the call
## notice's decline button, and so does a call left unanswered until the bus reaches a
## planet. A call ends unanswered, at no cost, when its caller leaves the
## bus.
## A finished quest stays among [method get_quests] for [constant SHOWN_SECONDS], so its
## row shows how it ended.

## A quest was taken on, or the one under way ended.
signal changed
## [param quest] was taken on.
signal quest_added(quest: Quest)
## The player answered [param passenger], picked up from a capsule adrift: on board now when
## [param accepted], and otherwise left where they are.
signal rescue_answered(passenger: Passenger, accepted: bool)
## [param quest], finished a while ago, is no longer shown.
signal quest_removed(quest: Quest)

## Seconds into a run before the first call, and between one call or quest ending and the
## next call: a random value between the two.
const FIRST_CALL_SECONDS := 30.0
const CALL_MIN_SECONDS := 75.0
const CALL_MAX_SECONDS := 120.0
## How many times as long that wait is while [member vips_call], so passengers call less
## often there.
const VIP_LEVEL_WAIT := 1.5
## How many passengers the player has delivered before anyone calls.
const FIRST_CALL_DELIVERIES := 13
## Until the player has delivered this many passengers, the wait from one call or quest
## ending to the next call is short, a random value between these two, so a new player
## meets a second quest soon after the first.
const EARLY_DELIVERIES := 20
const EARLY_CALL_MIN_SECONDS := 35.0
const EARLY_CALL_MAX_SECONDS := 50.0
## Seconds from picking a passenger up from a capsule to their transmission opening.
const RESCUE_SECONDS := 1.5
## Seconds before trying again when nobody on board could call.
const RETRY_SECONDS := 3.0
## Seconds the bus has flown before anyone calls, so a call never lands on leaving.
const FLIGHT_SECONDS := 2.0
## Nobody calls this close to getting off, in seconds.
const ARRIVING_SECONDS := 6.0
## What declining a quest, or never answering the call, does to the caller's happiness, and
## what failing one does.
const DECLINE_SHOCK := -5.0
const FAIL_SHOCK := -15.0
## How many times as likely a returning passenger is to be the one who calls as anyone
## else who could. It changes who calls, never how often.
const RETURNING_WEIGHT := 3.0
## Seconds a finished quest stays among the quests.
const SHOWN_SECONDS := 8.0
## Seconds the notice of how a quest ended shows.
const NOTICE_SECONDS := 4.0
## What the quick text over the bus says when a quest ends.
const COMPLETED_TEXT := "Quest completed!"
const COMPLETED_ICON := preload("res://shared/icons/circle_check.svg")
const FAILED_TEXT := "Quest failed!"
const FAILED_ICON := preload("res://shared/icons/circle_x.svg")

## Whether anyone calls. A quest under way carries on either way.
@export var enabled := true
## What a done quest adds to the caller's happiness at once, and to the most they can reach
## for the rest of their ride ([method Passenger.admire]): enough to lift a clean ride on a
## bare bus to five stars.
@export_range(0.0, 40.0, 0.5) var done_happiness := 20.0
@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Tells the quests' goals what happens in the game.
@export var quests: GoalTracker
## Whose rocks a ride through them asks for. None, and nobody asks for one.
@export var asteroid_field: AsteroidField
## Stamps how a quest ended over the bus.
@export var quick_text: BusQuickText

## Whether VIPs call in the star system the bus works in ([VipCalls]), and so passengers
## call less often. The [Progression] sets it.
var vips_call := false

## The quest the pointer is on in the goal panel, or null. The panel sets it.
var pointed: Quest

var _planets: Array[Planet] = []
var _ledger: Ledger
# Prices and times the trips quests ask for.
var _waiting: WaitingPassengers
# Which star system the bus works in, counted from 0 in the order they open. Quests pay by
# it, and it sets who calls and what they ask for.
var _level := 0
# Made once it is in the tree: a scene stores every member of a node another node exports,
# and dice made here would differ in every save of it.
var _rng: RandomNumberGenerator
var _until_call := FIRST_CALL_SECONDS
# Whether the next call was asked for, so it comes however few have been delivered.
var _call_asked := false
# Seconds the bus has flown since it last stopped.
var _flight_seconds := 0.0
# The call ringing, and who calls.
var _call: Notice
var _caller: Passenger
# The quest on offer in the transmission panel, the one under way, and a VIP's tour under
# way.
var _offer: Quest
var _quest: Quest
var _tour: VipTourQuest
# Who was picked up from a capsule and has yet to call, and the seconds until they do.
var _rescued: Passenger
var _rescue_wait := 0.0
# Seconds each finished quest still shows.
var _shown: Dictionary[Quest, float] = {}


func _ready() -> void:
	if not _rng:
		_rng = RandomNumberGenerator.new()
	if quests:
		quests.goal_completed.connect(_on_goal_completed)
		quests.goal_failed.connect(_on_goal_failed)


func _process(delta: float) -> void:
	for quest: Quest in _shown.keys():
		_shown[quest] -= delta
		if _shown[quest] <= 0.0:
			_shown.erase(quest)
			quests.remove(quest.goal)
			quest_removed.emit(quest)
	if not bus or not cabin or not _waiting:
		return
	var flying := bus.state == FrameshiftBus.State.FLYING and not bus.is_towing()
	_flight_seconds = _flight_seconds + delta if flying and not bus.is_stopping() else 0.0
	if _call:
		_watch_call()
		return
	if _offer:
		_watch_offer()
		return
	if _quest or not enabled:
		return
	if _rescued:
		_call_rescued(delta)
	else:
		_wait_for_call(delta)


## Tells it the run's [param planets], which quests send passengers to, the
## [param ledger] their rewards go into, and [param waiting], which prices and times the
## trips they ask for. [param level] is the star system the bus works in, counted from 0 in
## the order they open: quests pay by it, and it sets who calls and what they ask for.
func start(planets: Array[Planet], ledger: Ledger, waiting: WaitingPassengers, level := 0) -> void:
	_planets = planets
	_ledger = ledger
	_waiting = waiting
	_level = level


## Makes the dice repeatable.
func seed_dice(value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = value


## The quest on offer in the transmission panel, before the player answers, or null.
func get_offer() -> Quest:
	return _offer


## Whether a passenger's call rings, before it is answered or goes, or one picked up from a
## capsule is about to call.
func is_calling() -> bool:
	return _call != null or _rescued != null


## Whether a passenger picked up from a capsule now could call at once: with calls on and
## no call, offer, quest or transmission in the way. A VIP's tour isn't in the way.
func can_rescue() -> bool:
	return is_line_free() and _quest == null


## Whether nobody is on the line: calls are on, and no call, offer or transmission is in
## the way, whatever quests are under way.
func is_line_free() -> bool:
	var busy := _call != null or _offer != null or _rescued != null
	return enabled and not busy and not transmission_panel.is_open()


## The quest a passenger asked for under way, or null.
func get_quest() -> Quest:
	return _quest


## The VIP's tour under way, or null.
func get_tour() -> VipTourQuest:
	return _tour


## The quests under way, if any, after those just finished, oldest first.
func get_quests() -> Array[Quest]:
	var shown: Array[Quest] = []
	shown.assign(_shown.keys())
	for quest: Quest in [_quest, _tour]:
		if quest:
			shown.append(quest)
	return shown


## Has someone call as soon as anyone can, whatever the wait since the last call and
## however few passengers have been delivered.
func call_soon() -> void:
	_until_call = 0.0
	_call_asked = true


## [param passenger] was picked up from a capsule adrift: [constant RESCUE_SECONDS] later
## the transmission of their [RescueQuest] opens, however long since the last call and
## however few passengers have been delivered. Ask [method can_rescue] first. Nothing once
## they have left the bus. They aren't on board yet: accepting boards them
## ([signal rescue_answered]).
func rescue(passenger: Passenger) -> void:
	_rescued = passenger
	_rescue_wait = RESCUE_SECONDS


## The quests under way, for a save game, each with its passenger as their place among
## [param on_board]. Empty with none.
func to_save(on_board: Array[Passenger]) -> Array[Dictionary]:
	var saved: Array[Dictionary] = []
	for quest: Quest in [_quest, _tour]:
		if quest and quest.passenger in on_board:
			var one := quest.to_save()
			one["passenger"] = on_board.find(quest.passenger)
			saved.append(one)
	return saved


## Puts back the quests [method to_save] gave, each about the passenger at its place among
## [param on_board], with its planet found by name in [param planets].
func load_save(
	saved: Array, on_board: Array[Passenger], planets: Dictionary[String, Planet]
) -> void:
	for one: Dictionary in saved:
		var index := int(one.get("passenger", -1))
		if index < 0 or index >= on_board.size():
			continue
		var quest := QuestKinds.make(str(one.get("kind", "")))
		if quest and quest.restore(one, on_board[index], planets):
			take_on(quest)


## Makes [param quest], whose goal is built, a quest under way, a VIP's tour apart from the
## rest: tracks its goal and flags its passenger.
func take_on(quest: Quest) -> void:
	if quest is VipTourQuest:
		_tour = quest
	else:
		_quest = quest
	quest.passenger.quest_line = quest.goal.get_text()
	quest.begin(cabin)
	quests.add(quest.goal)
	quest_added.emit(quest)


# Whether a call could come now: the bus has flown a moment, no transmission shows, and
# the player has delivered enough passengers.
func _is_time_to_call() -> bool:
	if _flight_seconds < FLIGHT_SECONDS or transmission_panel.is_open():
		return false
	return _call_asked or not _ledger or _ledger.get_rating_count() >= FIRST_CALL_DELIVERIES


# Someone on board who could call now: awake, not about to get off, and with a quest to
# offer as things stand. A returning passenger is RETURNING_WEIGHT times as likely as
# anyone else.
func _pick_caller() -> Passenger:
	var able: Array[Passenger] = []
	var weights := PackedFloat32Array()
	for passenger: Passenger in cabin.get_passengers():
		var touring := _tour and passenger == _tour.passenger
		if passenger.asleep or touring or _is_arriving(passenger):
			continue
		if _plan(passenger):
			able.append(passenger)
			weights.append(RETURNING_WEIGHT if passenger.returning else 1.0)
	if able.is_empty():
		return null
	# With nobody returning the roll is the plain one, so such a run plays as before.
	if not able.any(func(passenger: Passenger) -> bool: return passenger.returning):
		return able[_rng.randi_range(0, able.size() - 1)]
	return able[_rng.rand_weighted(weights)]


# The quest [param passenger] would offer as things stand, or null when none suits: the
# first of [QuestPicks]'s that does.
func _plan(passenger: Passenger) -> Quest:
	var picks := QuestPicks.for_passenger(
		passenger, _waiting.business, _level, asteroid_field, _rng
	)
	for quest: Quest in picks:
		quest.level = _level
		if quest.plan(passenger, bus, _planets, _waiting, _rng):
			return quest
	return null


func _plan_rescue(passenger: Passenger) -> Quest:
	var quest := RescueQuest.new()
	quest.level = _level
	return quest if quest.plan(passenger, bus, _planets, _waiting, _rng) else null


func _is_arriving(passenger: Passenger) -> bool:
	if bus.get_next_planet() != passenger.destination:
		return false
	return bus.estimate_time_to_next_planet() < ARRIVING_SECONDS


# The call rings until it is answered, its caller leaves the bus, or the bus reaches a
# planet or is towed, which the caller takes as a no.
func _watch_call() -> void:
	var riding := _caller in cabin.get_passengers()
	var in_space := bus.state in [FrameshiftBus.State.FLYING, FrameshiftBus.State.HOLDING]
	if riding and in_space and not bus.is_towing():
		return
	_call.dismiss()
	_call = null
	if riding:
		_caller.shock(DECLINE_SHOCK, HappinessCause.Type.QUEST_DECLINED)
	_rest()


# Counts down to the next call, and once it is time, has someone on board call.
func _wait_for_call(delta: float) -> void:
	_until_call -= delta
	if _until_call > 0.0 or not _is_time_to_call():
		return
	_caller = _pick_caller()
	if not _caller:
		_until_call = RETRY_SECONDS
		return
	_ring()


func _ring() -> void:
	_call = notices.announce_transmission(Transmission.from_passenger(_caller), true, true)
	_call.action_pressed.connect(_on_call_answered)
	_call.declined.connect(_on_call_declined)


# The passenger picked up from a capsule calls once their wait is over, outside a stop.
func _call_rescued(delta: float) -> void:
	_rescue_wait -= delta
	if _rescue_wait > 0.0 or transmission_panel.is_open() or cabin.is_stopping():
		return
	_caller = _rescued
	_rescued = null
	_open_offer(_plan_rescue(_caller))


func _on_call_answered() -> void:
	if not _call:
		return
	_call = null
	_open_offer(_plan(_caller))


# The transmission of [param quest] opens for the player to answer, or nobody calls for a
# while when it is null.
func _open_offer(quest: Quest) -> void:
	_offer = quest
	if not _offer:
		_rest()
		return
	transmission_panel.answered.connect(_on_answered, CONNECT_ONE_SHOT)
	transmission_panel.open(_offer.get_transmission())


# Declined from the notice, before hearing the quest: a no all the same.
func _on_call_declined() -> void:
	if not _call:
		return
	_call = null
	if _caller in cabin.get_passengers():
		_caller.shock(DECLINE_SHOCK, HappinessCause.Type.QUEST_DECLINED)
	_rest()


# The offer stands while its transmission shows. Should that close unanswered, as when
# something else takes the panel away, the offer is off, at no cost.
func _watch_offer() -> void:
	if transmission_panel.is_open():
		return
	if transmission_panel.answered.is_connected(_on_answered):
		transmission_panel.answered.disconnect(_on_answered)
	if _offer is RescueQuest:
		rescue_answered.emit(_offer.passenger, false)
	_offer = null
	_rest()


func _on_answered(accepted: bool) -> void:
	var quest := _offer
	_offer = null
	if quest is RescueQuest:
		accepted = accepted and cabin.board(quest.passenger)
		rescue_answered.emit(quest.passenger, accepted)
		if not accepted:
			_rest()
			return
	if not quest or quest.passenger not in cabin.get_passengers():
		_rest()
		return
	if not accepted:
		quest.passenger.shock(DECLINE_SHOCK, HappinessCause.Type.QUEST_DECLINED)
		_rest()
		return
	quest.accept()
	take_on(quest)
	changed.emit()


func _on_goal_completed(goal: Goal) -> void:
	var quest := _under_way(goal)
	if not quest:
		return
	if _ledger:
		_ledger.earn(quest.reward_credits)
		if quest.reward_research > 0:
			_ledger.earn_research(quest.reward_research)
	if quest.passenger in cabin.get_passengers():
		quest.passenger.admire(done_happiness, true)
	notices.push("Quest done: %s" % goal.get_text(), Notice.Kind.INFO, false, NOTICE_SECONDS)
	if quick_text:
		quick_text.show_text(COMPLETED_TEXT, COMPLETED_ICON, BusQuickText.Kind.GAIN)
	_finish(quest)


func _on_goal_failed(goal: Goal) -> void:
	var quest := _under_way(goal)
	if not quest:
		return
	if quest.passenger in cabin.get_passengers():
		quest.passenger.shock(FAIL_SHOCK, HappinessCause.Type.QUEST_FAILED)
	notices.push("Quest failed: %s" % goal.get_text(), Notice.Kind.WARNING, false, NOTICE_SECONDS)
	if quick_text:
		quick_text.show_text(FAILED_TEXT, FAILED_ICON, BusQuickText.Kind.LOSS)
	_finish(quest)


# The quest under way whose goal is [param goal], or null.
func _under_way(goal: Goal) -> Quest:
	for quest: Quest in [_quest, _tour]:
		if quest and quest.goal == goal:
			return quest
	return null


# A tour ending leaves the wait for the next passenger's call as it is.
func _finish(quest: Quest) -> void:
	quest.passenger.quest_line = ""
	_shown[quest] = SHOWN_SECONDS
	if quest == _tour:
		_tour = null
	else:
		_quest = null
		_rest()
	changed.emit()


# Nobody calls for a while.
func _rest() -> void:
	_caller = null
	_call_asked = false
	if _ledger and _ledger.get_rating_count() < EARLY_DELIVERIES:
		_until_call = _rng.randf_range(EARLY_CALL_MIN_SECONDS, EARLY_CALL_MAX_SECONDS)
	else:
		_until_call = _rng.randf_range(CALL_MIN_SECONDS, CALL_MAX_SECONDS)
	if vips_call:
		_until_call *= VIP_LEVEL_WAIT
