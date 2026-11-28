class_name FastForward
extends Node
## The debug panel's Fast-forward ([method Campaign.fast_forward]): a new run that comes to a
## later level as a player would, so the level can be tested as they see it, and each level
## before it can be played again as a player who came through it would. The run starts in
## Level 1, docked at its home planet, with what a player has as they are promoted out of it:
## credits, research points, ratings and upgrades rolled within what balance runs measured
## there, research open on the stages they would have, the tutorial done and every feature
## hint they would have met before Level 2 seen. Then the bus takes the jump, as answering The
## Boss's promotion call does. A level on the way it only passes through: the jump there has
## no loading screen, its start is kept as the player's first save there would keep it, the
## bus docked at its home planet, and the run tops up to what a player has as they are
## promoted out of it before the next jump. The last jump has the level's loading screen, its
## arrival call and its starting passengers.
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
	&"requests": 1,
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
## Takes the jumps.
@export var progression: Progression
@export var system_jump: SystemJump
## Keeps where each level passed through began.
@export var saver: GameSaver
## Where The Boss waits in the last system, where a run fast-forwarded to the ending docks.
@export var ending_planet: Planet
## The goals met for the ending, the VIPs' among them.
@export var goals: GoalTracker
@export var vips: VipCalls
## Has The Boss wait at [member ending_planet] for the ending.
@export var boss_pick_up: BossPickUp

# The level number the run fast-forwards to, from 2, one past the last for the ending, or 0.
var _level := 0
var _ledger: Ledger
var _rng := RandomNumberGenerator.new()


## Starts the run in Level 1, on the way to the level numbered [param level]: [param bus]
## docked at its home planet and [param ledger] holding what a player has there. One past the
## last level is the ending: the run starts in the last system, docked at
## [member ending_planet]. Call it before the scene is ready, as
## [method GameSaver.place_world] does. Gives what the [StarMap] keeps, for
## [method StarMap.restore].
func place(level: int, bus: FrameshiftBus, ledger: Ledger) -> Dictionary:
	_rng.randomize()
	var systems := star_map.get_systems()
	_level = clampi(level, 2, systems.size() + 1)
	_ledger = ledger
	if _is_ending():
		bus.start_planet = ending_planet
		_fill_ledger(_level)
		return SavedStarMap.make(systems.size(), false, String(systems.back().name))
	bus.start_planet = systems[0].home
	_fill_ledger(2)
	return SavedStarMap.make(1, false, String(systems[0].name))


## Once the scene has built the run: brings research to where the player would have it, and,
## once the screen has faded in, takes the jumps, passing through each level before the one it
## fast-forwards to, or for the ending meets every goal and has The Boss wait where the bus
## is docked.
func apply() -> void:
	research_lab.get_research().open()
	SaveGame.mark_tutorial_done()
	# The castaway turns up in Vela.
	waiting.castaway_met = true
	_fill_research(_level if _is_ending() else 2)
	while SceneFlow.is_busy():
		await get_tree().process_frame
	if _is_ending():
		_meet_goals()
		boss_pick_up.begin()
		return
	var shows_loading_screen := system_jump.shows_loading_screen
	for level: int in range(3, _level + 1):
		system_jump.shows_loading_screen = false
		progression.advance()
		var system: StarSystem = await system_jump.finished
		system_jump.shows_loading_screen = shows_loading_screen
		saver.save_at(system.home)
		_fill_ledger(level)
		_fill_research(level)
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


# Rolls what a player has in the ledger as the bus arrives in the level numbered
# [param level]: credits, research points and the rides rated, counting those rated already.
func _fill_ledger(level: int) -> void:
	var arrival := _get_arrival(level)
	_ledger.credits = _roll_int(arrival.credits)
	var points := _roll_int(arrival.points) - _ledger.get_research()
	if points > 0:
		_ledger.earn_research(points)
	elif points < 0:
		_ledger.spend_research(-points)
	_rate(_roll_int(arrival.rides), _roll(arrival.average), _roll(arrival.recent))


# Brings research to where a player has it as the bus arrives in the level numbered
# [param level]: open on a stage for each level before, with the rolled number of upgrades
# researched, and keeps the hints met before that level as seen.
func _fill_research(level: int) -> void:
	var research := research_lab.get_research()
	while research.get_open_stages() < level - 1:
		research.open_next_stage()
	var upgrades := _roll_int(_get_arrival(level).upgrades) - _count_researched()
	for i: int in upgrades:
		var open := _get_researchable()
		if open.is_empty():
			break
		research.research(open[_rng.randi() % open.size()])
	for hint: StringName in HINT_LEVELS:
		if HINT_LEVELS[hint] < level:
			SaveGame.mark_hint_seen(hint)
	# The first Business passenger turns up at the first stop in Lyra.
	waiting.first_business_dealt = level > 2


func _get_arrival(level: int) -> Dictionary:
	return ARRIVALS.get(level, ARRIVALS[ARRIVALS.keys().max()])


# How many upgrades are researched.
func _count_researched() -> int:
	var research := research_lab.get_research()
	var count := 0
	for tree: ResearchTree in research_lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			if research.is_researched(upgrade):
				count += 1
	return count


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


# Rates rides into the ledger until it has [param rides] in all: whole stars for the last
# [constant Ledger.RECENT_RATINGS], about [param recent] on average, and the rest at whatever
# brings every ride's to about [param average], counting those rated already.
func _rate(rides: int, average: float, recent: float) -> void:
	var rated := _ledger.get_rating_count()
	var added := maxi(rides - rated, 0)
	var last: Array[float] = []
	for i: int in mini(added, Ledger.RECENT_RATINGS):
		var stars := floorf(recent) + (1.0 if _rng.randf() < fmod(recent, 1.0) else 0.0)
		last.append(stars)
	var earlier := added - last.size()
	if earlier > 0:
		var total := _ledger.get_average_rating() * rated
		for stars: float in last:
			total += stars
		var each := (average * (rated + added) - total) / earlier
		for i: int in earlier:
			_ledger.rate(each)
	for stars: float in last:
		_ledger.rate(stars)


func _roll(ends: Vector2) -> float:
	return _rng.randf_range(ends.x, ends.y)


func _roll_int(ends: Vector2i) -> int:
	return _rng.randi_range(ends.x, ends.y)
