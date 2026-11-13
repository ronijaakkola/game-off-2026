class_name QuestGiver
extends Node
## Gives the player quests. Every so often while the bus flies, a Business passenger on
## board calls:
## an incoming transmission notice, whose Answer opens their [Quest]'s transmission. One
## call or quest at a time: nobody calls while a quest is under way, and the wait until
## the next call starts only once it has ended.
## Accepting makes the quest's change, tracks its goal in [member quests] and flags the
## passenger. A completed quest pays its reward; a failed one costs the passenger
## [constant FAIL_SHOCK] if they still ride, so nothing more when a kick failed it.
## Declining costs them [constant DECLINE_SHOCK], and so does a call left unanswered until
## the bus reaches a planet. A call ends unanswered, at no cost, when its caller leaves the
## bus.
## A finished quest stays among [method get_quests] for [constant SHOWN_SECONDS], so its
## row shows how it ended.

## A quest was taken on, or the one under way ended.
signal changed
## [param quest] was taken on.
signal quest_added(quest: Quest)
## [param quest], finished a while ago, is no longer shown.
signal quest_removed(quest: Quest)

## Seconds into a run before the first call, and between one call or quest ending and the
## next call: a random value between the two. Only a Business passenger calls, so the
## real wait is longer: until one rides.
const FIRST_CALL_SECONDS := 30.0
const CALL_MIN_SECONDS := 30.0
const CALL_MAX_SECONDS := 60.0
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
## Seconds a finished quest stays among the quests.
const SHOWN_SECONDS := 8.0
## Seconds the notice of how a quest ended shows.
const NOTICE_SECONDS := 4.0

## Whether anyone calls. A quest under way carries on either way.
@export var enabled := true
@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Tells the quests' goals what happens in the game.
@export var quests: GoalTracker

var _planets: Array[Planet] = []
var _ledger: Ledger
# Prices and times the trips quests ask for.
var _waiting: WaitingPassengers
# Made once it is in the tree: a scene stores every member of a node another node exports,
# and dice made here would differ in every save of it.
var _rng: RandomNumberGenerator
var _until_call := FIRST_CALL_SECONDS
# Seconds the bus has flown since it last stopped.
var _flight_seconds := 0.0
# The call ringing, and who calls.
var _call: Notice
var _caller: Passenger
# The quest on offer in the transmission panel, and the one under way.
var _offer: Quest
var _quest: Quest
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
	if _offer or _quest or not enabled:
		return
	_until_call -= delta
	if _until_call > 0.0 or _flight_seconds < FLIGHT_SECONDS or transmission_panel.is_open():
		return
	_caller = _pick_caller()
	if not _caller:
		_until_call = RETRY_SECONDS
		return
	_call = notices.announce_transmission()
	_call.action_pressed.connect(_on_call_answered)


## Tells it the run's [param planets], which quests send passengers to, the
## [param ledger] their rewards go into, and [param waiting], which prices and times the
## trips they ask for.
func start(planets: Array[Planet], ledger: Ledger, waiting: WaitingPassengers) -> void:
	_planets = planets
	_ledger = ledger
	_waiting = waiting


## Makes the dice repeatable.
func seed_dice(value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = value


## The quest under way, or null.
func get_quest() -> Quest:
	return _quest


## The quest under way, if any, after those just finished, oldest first.
func get_quests() -> Array[Quest]:
	var shown: Array[Quest] = []
	shown.assign(_shown.keys())
	if _quest:
		shown.append(_quest)
	return shown


## Has someone call as soon as anyone can, whatever the wait since the last call.
func call_soon() -> void:
	_until_call = 0.0


## The quest under way, for a save game, with its passenger as their place among
## [param on_board]. Empty with none.
func to_save(on_board: Array[Passenger]) -> Dictionary:
	if not _quest or _quest.passenger not in on_board:
		return {}
	var saved := _quest.to_save()
	saved["passenger"] = on_board.find(_quest.passenger)
	return saved


## Puts back the quest [method to_save] gave, about the passenger at its place among
## [param on_board].
func load_save(saved: Dictionary, on_board: Array[Passenger]) -> void:
	var index := int(saved.get("passenger", -1))
	if index < 0 or index >= on_board.size():
		return
	if saved.get("kind", "") != ExpressQuest.KIND:
		return
	var quest := ExpressQuest.new()
	quest.restore(saved, on_board[index])
	take_on(quest)


## Makes [param quest], whose goal is built, the quest under way: tracks its goal and
## flags its passenger.
func take_on(quest: Quest) -> void:
	_quest = quest
	quest.passenger.quest_line = quest.goal.get_text()
	quests.add(quest.goal)
	quest_added.emit(quest)


# Someone on board who could call now: a Business passenger, awake, not about to get off,
# and with a quest to offer as things stand. Only Business for now, while quests are tried
# out, so who calls is easy to tell and a bus of Commuters is left alone.
func _pick_caller() -> Passenger:
	var able: Array[Passenger] = []
	for passenger: Passenger in cabin.get_passengers():
		if passenger.type != _waiting.business or passenger.asleep or _is_arriving(passenger):
			continue
		if _plan(passenger):
			able.append(passenger)
	return able[_rng.randi_range(0, able.size() - 1)] if not able.is_empty() else null


# The quest [param passenger] would offer as things stand, or null when none suits.
func _plan(passenger: Passenger) -> Quest:
	var quest := ExpressQuest.new()
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
		_caller.shock(DECLINE_SHOCK)
	_rest()


func _on_call_answered() -> void:
	if not _call:
		return
	_call = null
	_offer = _plan(_caller)
	if not _offer:
		_rest()
		return
	transmission_panel.answered.connect(_on_answered, CONNECT_ONE_SHOT)
	transmission_panel.open(_offer.get_transmission())


func _on_answered(accepted: bool) -> void:
	var quest := _offer
	_offer = null
	if not accepted:
		quest.passenger.shock(DECLINE_SHOCK)
		_rest()
		return
	quest.accept()
	take_on(quest)
	changed.emit()


func _on_goal_completed(goal: Goal) -> void:
	if not _quest or goal != _quest.goal:
		return
	if _ledger:
		_ledger.earn(_quest.reward_credits)
		for race: Race.Type in _quest.reward_research:
			_ledger.earn_research(race, _quest.reward_research[race])
	notices.push("Quest done: %s" % goal.get_text(), Notice.Kind.INFO, false, NOTICE_SECONDS)
	_finish()


func _on_goal_failed(goal: Goal) -> void:
	if not _quest or goal != _quest.goal:
		return
	if _quest.passenger in cabin.get_passengers():
		_quest.passenger.shock(FAIL_SHOCK)
	notices.push("Quest failed: %s" % goal.get_text(), Notice.Kind.WARNING, false, NOTICE_SECONDS)
	_finish()


func _finish() -> void:
	_quest.passenger.quest_line = ""
	_shown[_quest] = SHOWN_SECONDS
	_quest = null
	_rest()
	changed.emit()


# Nobody calls for a while.
func _rest() -> void:
	_caller = null
	_until_call = _rng.randf_range(CALL_MIN_SECONDS, CALL_MAX_SECONDS)
