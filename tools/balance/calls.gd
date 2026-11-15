extends RefCounted
## How the scripted player answers a passenger's call with a quest. It sees the call
## notice, answers after a moment's thought, and takes the quest on or declines it by the
## policy: "quests" is "accept" (the default), "decline", "ignore" (left ringing, which the
## caller takes as a no at the next planet) or "off" (nobody calls, as before quests).
## "quest_max_detour" declines a quest whose planet adds more than that many units to the
## way to the nearest planet someone else on board is going to. "call_think" is the
## seconds from the call ringing to the answer. An accepted express quest sets the course
## to its planet at once.

const Detour := preload("res://tools/balance/detour.gd")
## What the call notice says, as [method NoticeStack.announce_transmission] puts it.
const CALL_TEXT := "Incoming transmission"

## Calls seen, answered, taken on, declined, and quests done and failed, with what the
## done ones paid.
var calls := 0
var answered := 0
var accepted := 0
var declined := 0
var done := 0
var failed := 0
var credits := 0
var points := 0
## What happened since the last dock decision, for a player who decides turn by turn.
var news: Array[String] = []

var _policy: Dictionary
var _rng: RandomNumberGenerator
var _giver: QuestGiver
var _panel: TransmissionPanel
var _notices: NoticeStack
var _bus: FrameshiftBus
var _cabin: Cabin
var _detour: Detour
var _call: Notice
var _answer_in := 0.0
# Seconds played, and when each call rang.
var _time := 0.0
var _call_times: Array[float] = []
var _quest: Quest


func _init(
	policy: Dictionary, rng: RandomNumberGenerator, system: SolarSystem, detour: Detour
) -> void:
	_policy = policy
	_rng = rng
	_detour = detour
	_giver = system.get_node(^"%QuestGiver") as QuestGiver
	_panel = system.get_node(^"TransmissionPanel") as TransmissionPanel
	_notices = system.get_node(^"%Notices") as NoticeStack
	_bus = system.get_node(^"%Bus") as FrameshiftBus
	_cabin = system.get_node(^"%Cabin") as Cabin
	_giver.enabled = str(policy.get("quests", "accept")) != "off"
	_giver.quest_added.connect(_on_quest_added)
	var quests := system.get_node(^"%Quests") as GoalTracker
	quests.goal_completed.connect(_on_goal_ended.bind(true))
	quests.goal_failed.connect(_on_goal_ended.bind(false))


## Every frame: notices a new call, and answers it once the thought is over.
func tick(delta: float) -> void:
	_time += delta
	if is_instance_valid(_call) and not _call.is_leaving():
		_answer_in -= delta
		if _answer_in <= 0.0 and str(_policy.get("quests", "accept")) != "ignore":
			_answer()
		return
	_call = null
	for notice: Notice in _notices.get_notices():
		if notice.get_text().begins_with(CALL_TEXT) and not notice.is_leaving():
			_call = notice
			calls += 1
			_call_times.append(snappedf(_time, 0.1))
			_answer_in = float(_policy.get("call_think", 2.0)) * _rng.randf_range(0.5, 1.5)
			return


## What was counted, as plain data.
func report() -> Dictionary:
	return {
		"calls": calls,
		"call_times": _call_times,
		"answered": answered,
		"accepted": accepted,
		"declined": declined,
		"done": done,
		"failed": failed,
		"credits": credits,
		"points": points,
	}


# Answer opens the transmission, which pauses the game, and the answer is given at once:
# reading it costs no game time.
func _answer() -> void:
	var call := _call
	_call = null
	# As the notice's own button does: it answers, then leaves, so it is never seen again.
	call.action_pressed.emit()
	call.dismiss()
	var offer := _giver.get_offer()
	if not offer or not _panel.is_open():
		return
	answered += 1
	_panel.skip()
	if str(_policy.get("quests", "accept")) == "accept" and _is_worth(offer):
		_panel.accept()
		return
	declined += 1
	news.append("%s called to go to %s instead; declined" % [offer.passenger.name, _name(offer)])
	_panel.close()


# Whether the detour to the quest's planet is short enough for everyone else on board.
func _is_worth(offer: Quest) -> bool:
	var limit := float(_policy.get("quest_max_detour", INF))
	var planet := offer.get_planet()
	if is_inf(limit) or not planet:
		return true
	var from := _bus.global_position
	var via := planet.get_body_global_position()
	var detour := INF
	for passenger: Passenger in _cabin.get_passengers():
		if passenger == offer.passenger:
			continue
		var to := passenger.destination.get_body_global_position()
		detour = minf(detour, from.distance_to(via) + via.distance_to(to) - from.distance_to(to))
	return is_inf(detour) or detour <= limit


func _on_quest_added(quest: Quest) -> void:
	_quest = quest
	accepted += 1
	news.append("%s called to go to %s instead; accepted" % [quest.passenger.name, _name(quest)])
	if quest.get_planet():
		_detour.plot(quest.get_planet())


func _on_goal_ended(goal: Goal, completed: bool) -> void:
	if not _quest or goal != _quest.goal:
		return
	if completed:
		done += 1
		credits += _quest.reward_credits
		for race: Race.Type in _quest.reward_research:
			points += _quest.reward_research[race]
	else:
		failed += 1
	news.append("Quest %s: %s" % ["done" if completed else "failed", goal.get_text()])
	_quest = null


func _name(quest: Quest) -> String:
	var planet := quest.get_planet()
	return planet.display_name if planet else "?"
