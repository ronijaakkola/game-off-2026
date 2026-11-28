class_name FastForward
extends Node
## The debug panel's Fast-forward ([method Campaign.fast_forward]): a new run that comes to a
## later level as a player would, so the level can be tested as they see it. The run starts in
## the level before, docked at its home planet, with what a player has as they are promoted
## out of it: credits, research points, ratings and upgrades rolled within what balance runs
## measured there, research open on the stages they would have, the tutorial done and every
## feature hint they would have met before the level seen. Then the bus takes the jump, as
## answering The Boss's promotion call does, so the level begins with its loading screen,
## its arrival call and its starting passengers. Earlier levels keep no start of their own.
## Fast-forwarded to the ending, numbered one past the last level, the run starts in the last
## system instead, docked at [member ending_planet] with every goal there met and The Boss's
## call answered ([BossPickUp]), so the meeting plays as soon as the screen has faded in.

## What a player has, as balance runs (`tools/balance.py`, promote_to Lyra and Sol) measured
## it as the bus arrives, by the number of the level it arrives in, and for the ending (4) as
## the last system's goals are met: credits and research points left after researching, the
## rides rated, the average and recent rating, and how many upgrades are researched. Each is
## rolled between the two ends.
const ARRIVALS := {
	2:
	{
		credits = Vector2i(40, 420),
		points = Vector2i(2, 16),
		rides = Vector2i(18, 23),
		average = Vector2(3.65, 4.2),
		recent = Vector2(3.8, 4.4),
		upgrades = Vector2i(5, 9),
	},
	3:
	{
		credits = Vector2i(170, 1200),
		points = Vector2i(7, 29),
		rides = Vector2i(35, 54),
		average = Vector2(3.95, 4.35),
		recent = Vector2(4.1, 4.6),
		upgrades = Vector2i(12, 19),
	},
	4:
	{
		credits = Vector2i(500, 4400),
		points = Vector2i(45, 109),
		rides = Vector2i(83, 114),
		average = Vector2(4.2, 4.42),
		recent = Vector2(4.0, 5.0),
		upgrades = Vector2i(33, 35),
	},
}
## The level each feature hint is first met in, by its name in [constant FeatureHints.HINTS],
## and the research guide's beside them (fast_forward_test checks every hint is here).
const HINT_LEVELS := {
	&"goals": 1,
	&"quests": 1,
	&"heat_zone": 1,
	&"returning": 1,
	&"jump": 1,
	ResearchGuide.SEEN: 1,
	&"business": 2,
	&"asteroid_field": 2,
	&"warp_drive": 2,
	&"vip": 3,
}

@export var star_map: StarMap
@export var research_lab: ResearchLab
@export var waiting: WaitingPassengers
## Takes the jump.
@export var progression: Progression
## Where The Boss waits in the last system, where a run fast-forwarded to the ending docks.
@export var ending_planet: Planet
## The goals met for the ending, the VIPs' among them.
@export var goals: GoalTracker
@export var vips: VipCalls
## Has The Boss wait at [member ending_planet] for the ending.
@export var boss_pick_up: BossPickUp

# The level number the run fast-forwards to, from 2, one past the last for the ending, or 0.
var _level := 0
var _rng := RandomNumberGenerator.new()


## Starts the run in the level before the one numbered [param level]: [param bus] docked at its
## home planet and [param ledger] holding what a player has there. One past the last level is
## the ending: the run starts in the last system, docked at [member ending_planet]. Call it
## before the scene is ready, as [method GameSaver.place_world] does. Gives what the
## [StarMap] keeps, for [method StarMap.restore].
func place(level: int, bus: FrameshiftBus, ledger: Ledger) -> Dictionary:
	_rng.randomize()
	var systems := star_map.get_systems()
	_level = clampi(level, 2, systems.size() + 1)
	var system := systems[mini(_level, systems.size()) - 2]
	bus.start_planet = system.home
	if _is_ending():
		system = systems.back()
		bus.start_planet = ending_planet
	var arrival: Dictionary = ARRIVALS.get(_level, ARRIVALS[ARRIVALS.keys().max()])
	ledger.credits = _roll_int(arrival.credits)
	ledger.earn_research(_roll_int(arrival.points))
	_rate(ledger, _roll_int(arrival.rides), _roll(arrival.average), _roll(arrival.recent))
	return SavedStarMap.make(mini(_level - 1, systems.size()), false, String(system.name))


## Once the scene has built the run: opens research on the stages the player would have,
## researches the rolled upgrades, keeps the hints met before the level as seen, and, once the
## screen has faded in, takes the jump, or for the ending meets every goal and has The Boss
## wait where the bus is docked.
func apply() -> void:
	var research := research_lab.get_research()
	research.open()
	for stage: int in range(1, _level - 1):
		research.open_next_stage()
	var arrival: Dictionary = ARRIVALS.get(_level, ARRIVALS[ARRIVALS.keys().max()])
	for i: int in _roll_int(arrival.upgrades):
		var open := _get_researchable()
		if open.is_empty():
			break
		research.research(open[_rng.randi() % open.size()])
	SaveGame.mark_tutorial_done()
	for hint: StringName in HINT_LEVELS:
		if HINT_LEVELS[hint] < _level:
			SaveGame.mark_hint_seen(hint)
	# The castaway turns up in Vela, and the first Business passenger at the first stop in Lyra.
	waiting.castaway_met = true
	waiting.first_business_dealt = _level > 2
	while SceneFlow.is_busy():
		await get_tree().process_frame
	if _is_ending():
		_meet_goals()
		boss_pick_up.begin()
	else:
		progression.advance()


# Whether the run fast-forwards to the ending, past the last level.
func _is_ending() -> bool:
	return _level > star_map.get_systems().size()


# Every goal of the last system met, as when The Boss calls: VIPs have started calling there,
# which adds their goal, and each milestone is completed with its count reached. A standing
# goal holds by the rolled rating.
func _meet_goals() -> void:
	vips.load_save({"delivered": VipCalls.FIRST_DELIVERIES})
	for goal: Goal in goals.get_goals():
		if goal.is_standing():
			continue
		var done := {"state": Goal.State.COMPLETED}
		if goal is DeliveryCountGoal:
			done["delivered"] = (goal as DeliveryCountGoal).target
		elif goal is EarnCreditsGoal:
			done["earned"] = (goal as EarnCreditsGoal).target
		goal.load_save(done)


# Every upgrade the player could research now, the cost aside.
func _get_researchable() -> Array[Upgrade]:
	var research := research_lab.get_research()
	var found: Array[Upgrade] = []
	for tree: ResearchTree in research_lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			if (
				research.is_open(upgrade)
				and research.is_unlocked(upgrade)
				and not research.is_researched(upgrade)
			):
				found.append(upgrade)
	return found


# Rates [param rides] rides into [param ledger]: whole stars for the last
# [constant Ledger.RECENT_RATINGS], about [param recent] on average, and the rest at whatever
# brings every ride's to about [param average].
func _rate(ledger: Ledger, rides: int, average: float, recent: float) -> void:
	var last: Array[float] = []
	for i: int in mini(rides, Ledger.RECENT_RATINGS):
		var stars := floorf(recent) + (1.0 if _rng.randf() < fmod(recent, 1.0) else 0.0)
		last.append(stars)
	var earlier := rides - last.size()
	if earlier > 0:
		var last_total := 0.0
		for stars: float in last:
			last_total += stars
		var each := (average * rides - last_total) / earlier
		for i: int in earlier:
			ledger.rate(each)
	for stars: float in last:
		ledger.rate(stars)


func _roll(ends: Vector2) -> float:
	return _rng.randf_range(ends.x, ends.y)


func _roll_int(ends: Vector2i) -> int:
	return _rng.randi_range(ends.x, ends.y)
