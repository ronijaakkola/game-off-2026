class_name GameSaver
extends Node
## Keeps the run in the player's save game ([code]SaveGame[/code]) and puts a saved run
## back. Only a run the main menu started is saved or continued; a scene started any other
## way runs a new run and saves nothing.
## The run is saved at checkpoints: once something it keeps has changed and the bus waits
## at a planet with no stop under way. A new run saves at once, over any save, and starts
## docked at [member new_run_planet]. A continued run starts docked at the planet it was
## saved at, so quitting in flight loses only the flight. It keeps where each planet is on
## its orbit, the bus's planet, fuel and reserve, the [Ledger], the researched upgrades, whether
## research and which stages are open, the passengers on board and in every line, those
## who may come back, the goals'
## progress, the quest under way and how far through the star systems the player has got.
## The course, the charge and what passengers were doing start afresh.
## Putting a run back comes in two steps, so the scene builds a continued run as it builds
## a new one: [method place_world] before anything in the scene is ready, then
## [method start] once it is, which applies the rest on top.
## While [member holding], as through the tutorial, nothing is saved, so the save from
## before stays until the run first saves after it.

## A save from before research trees left their planets keys each upgrade by the planet its
## tree was at: the tree file each planet had then.
const PLANET_TREES: Dictionary[String, String] = {
	"Frost": "blue_tree",
	"Terra": "green_tree",
	"Giant": "orange_tree",
}
## Which layout of the research trees a save keys its upgrades by. A save from before the
## trees were laid out again keys them by the first layout, saved as no number.
const RESEARCH_LAYOUT := 2
## Where each upgrade the first layout kept somewhere else sits now, or "" for one that is
## gone, by its key then.
const FIRST_LAYOUT_PLACES: Dictionary[String, String] = {
	"blue_tree/0/0": "blue_tree/0/2",
	"blue_tree/1/1": "blue_tree/1/0",
	"blue_tree/1/2": "",
	"blue_tree/2/0": "blue_tree/2/2",
	"blue_tree/3/1": "",
	"blue_tree/3/2": "blue_tree/3/1",
	"blue_tree/3/4": "",
	"blue_tree/4/0": "blue_tree/4/2",
	"green_tree/2/3": "green_tree/3/3",
	"green_tree/3/2": "green_tree/4/2",
	"green_tree/3/4": "",
	"green_tree/4/1": "green_tree/4/0",
	"green_tree/4/3": "green_tree/4/4",
	"orange_tree/0/0": "orange_tree/0/2",
	"orange_tree/0/1": "orange_tree/0/0",
	"orange_tree/0/3": "orange_tree/0/4",
	"orange_tree/1/2": "orange_tree/1/1",
	"orange_tree/1/4": "orange_tree/1/3",
	"orange_tree/2/0": "orange_tree/2/2",
	"orange_tree/2/2": "orange_tree/2/1",
	"orange_tree/2/3": "orange_tree/2/4",
	"orange_tree/3/1": "orange_tree/3/0",
	"orange_tree/3/3": "",
	"orange_tree/3/4": "orange_tree/3/3",
	"orange_tree/4/0": "orange_tree/4/2",
	"orange_tree/4/2": "orange_tree/4/0",
	"orange_tree/5/1": "orange_tree/5/2",
}

## The bus whose planet, fuel and stats are kept.
@export var bus: FrameshiftBus
## Where a new run's bus starts docked, with the tutorial or without it.
@export var new_run_planet: Planet
## Who is on board.
@export var cabin: Cabin
@export var goals: GoalTracker
## Whose quests under way are kept.
@export var quest_giver: QuestGiver
## How close VIPs are to calling, so a VIP goal comes back before the goals' progress.
@export var vips: VipCalls
## Which upgrades are researched, whether research and which stages are open, and every
## research tree.
@export var research_lab: ResearchLab
## Which star systems are open and joined. The bus's planet says which one it works in.
@export var star_map: StarMap
## How close the next capsule is to holding the castaway.
@export var capsules: CapsuleField

## Who waits at each planet. The parent sets it before [method start].
var waiting: WaitingPassengers
## Whether saving waits. Changes made meanwhile are saved at the first checkpoint after.
var holding := false

var _recording := false
var _continued := false
var _tutorial := false
# The star system the run last saved in, so the first save in another is where its level
# began ([Campaign]).
var _saved_system := ""
var _saved: Dictionary = {}
var _ledger: Ledger
var _planets: Array[Planet] = []
# Something kept changed since the last save.
var _dirty := false


func _process(_delta: float) -> void:
	if _recording and _dirty and not holding and bus.is_at_planet() and not cabin.is_stopping():
		_write()


## Takes the run the main menu started, if any. A new one starts the bus at
## [member new_run_planet]. Continuing one, it puts [param planets]
## back on their orbits, the bus at its planet and [param ledger] as it was: call it before
## the scene is ready, so everything starts there and the HUD shows the saved values.
func place_world(planets: Array[Planet], ledger: Ledger) -> void:
	_planets = planets
	_ledger = ledger
	_recording = SaveGame.has_started_run()
	_tutorial = SaveGame.wants_tutorial()
	_saved = SaveGame.claim_run()
	_continued = not _saved.is_empty()
	_saved_system = SavedStarMap.get_system(SavedStarMap.of(_saved))
	if not _continued:
		if _recording and new_run_planet:
			bus.start_planet = new_run_planet
		return
	var by_name := _get_planets_by_name()
	var orbits: Dictionary = _saved.get("planets", {})
	for planet_name: String in orbits:
		if by_name.has(planet_name):
			by_name[planet_name].orbit_time = float(orbits[planet_name])
	var bus_planet: Planet = by_name.get(_saved.get("bus_planet", ""))
	if bus_planet:
		bus.start_planet = bus_planet
	ledger.load_save(_saved.get("ledger", {}))


## What the continued run kept of the [StarMap], for [method StarMap.restore]: empty for a
## new run. Only before [method start].
func get_saved_star_map() -> Dictionary:
	return SavedStarMap.of(_saved)


## Whether this run starts with the tutorial: a new run the main menu started with it, as
## it does until the player has been through it once.
func wants_tutorial() -> bool:
	return is_new_run() and _tutorial


## Keeps that the player has been through the tutorial, for a run the main menu started.
func finish_tutorial() -> void:
	if _recording:
		SaveGame.mark_tutorial_done()


## Whether the main menu started this run, new or continued, so it is saved.
func is_saved_run() -> bool:
	return _recording


## Whether the main menu started this run afresh, rather than continuing a save or the
## scene being run on its own.
func is_new_run() -> bool:
	return _recording and not _continued


## Once the scene has built its run: continuing one, puts back the upgrades, the fuel, the
## lines, the passengers on board and the goals' progress. From then on it saves at
## checkpoints.
func start() -> void:
	if _continued:
		_restore()
	_saved = {}
	bus.docked.connect(_on_changed.unbind(1))
	cabin.stop_finished.connect(_on_changed)
	cabin.kicked.connect(_on_changed.unbind(1))
	cabin.left_behind.connect(_on_changed.unbind(1))
	if quest_giver:
		quest_giver.changed.connect(_on_changed)
	if star_map:
		star_map.changed.connect(_on_changed)
	research_lab.get_research().researched.connect(_on_changed.unbind(1))
	research_lab.get_research().stage_opened.connect(_on_changed.unbind(1))
	research_lab.get_research().opened.connect(_on_changed)
	_ledger.credits_earned.connect(_on_changed.unbind(1))
	_ledger.credits_spent.connect(_on_changed.unbind(1))
	_ledger.credits_set.connect(_on_changed)
	_ledger.research_earned.connect(_on_changed.unbind(1))
	_ledger.research_spent.connect(_on_changed.unbind(1))
	# A new run takes over the save at once, so Continue never brings back an older one.
	_dirty = not _continued


func _on_changed() -> void:
	_dirty = true


func _write() -> void:
	_dirty = false
	var orbits := {}
	var lines := {}
	for planet: Planet in _planets:
		orbits[planet.name] = planet.orbit_time
		var seen := waiting.get_seen(planet)
		lines[planet.name] = {
			"seen": seen.map(func(p: Passenger) -> Dictionary: return p.to_save()),
			"unseen": waiting.count_at(planet) - seen.size(),
			"found_abandoned": planet.found_abandoned,
		}
	var researched: Array[String] = []
	var research := research_lab.get_research()
	var upgrades := _get_upgrades_by_key()
	for key: String in upgrades:
		if research.is_researched(upgrades[key]):
			researched.append(key)
	var on_board := cabin.get_passengers().map(func(p: Passenger) -> Dictionary: return p.to_save())
	var progress := goals.get_goals().map(func(g: Goal) -> Dictionary: return g.to_save())
	var run := {
		"planets": orbits,
		"bus_planet": String(bus.get_docked_planet().name),
		"fuel": bus.get_fuel_tank().fuel,
		"reserve_used": bus.get_fuel_tank().reserve_used,
		"ledger": _ledger.to_save(),
		"research": researched,
		"research_layout": RESEARCH_LAYOUT,
		"research_stages": research.get_open_stages(),
		"research_open": research.is_opened(),
		SavedStarMap.KEY: star_map.to_save() if star_map else {},
		"cabin": on_board,
		"lines": lines,
		"first_business": waiting.first_business_dealt,
		"castaway_met": waiting.castaway_met,
		"castaway_misses": capsules.castaway_misses if capsules else 0,
		"castaway_found": capsules.castaway_found if capsules else false,
		"returning": waiting.get_returning().to_save(),
		"goals": progress,
		"quests": quest_giver.to_save(cabin.get_passengers()) if quest_giver else [],
		"vips": vips.to_save() if vips else {},
	}
	SaveGame.write(run)
	if star_map:
		var system := String(star_map.get_current().name)
		# A save from before saves kept their system says nothing of where the run was, so
		# its first save is no entry.
		var entered := not _saved_system.is_empty() and system != _saved_system
		Campaign.record(run, system, star_map.count_done(), entered)
		_saved_system = system


# Upgrades first, so the seats and the tank are the saved bus's before anyone boards or
# the fuel goes in.
func _restore() -> void:
	var upgrades := _get_upgrades_by_key()
	var research := research_lab.get_research()
	var first_layout := int(_saved.get("research_layout", 1)) < RESEARCH_LAYOUT
	for key: Variant in _saved.get("research", []):
		var found := _upgrade_key(str(key))
		if first_layout:
			found = FIRST_LAYOUT_PLACES.get(found, found)
		if upgrades.has(found):
			research.research(upgrades[found])
	for stage: int in range(1, int(_saved.get("research_stages", 1))):
		research.open_next_stage()
	# A save from before research opened at once kept how many trees were open, and one
	# from before that had every tree open.
	var trees := int(_saved.get("research_trees", research_lab.trees.size()))
	if bool(_saved.get("research_open", trees > 0)):
		research.open()
	var tank := bus.get_fuel_tank()
	tank.fuel = clampf(float(_saved.get("fuel", tank.capacity)), 0.0, tank.capacity)
	tank.reserve_used = bool(_saved.get("reserve_used", false))
	var by_name := _get_planets_by_name()
	var types := _get_types_by_path()
	waiting.first_business_dealt = bool(_saved.get("first_business", false))
	waiting.castaway_met = bool(_saved.get("castaway_met", false))
	if capsules:
		capsules.castaway_misses = int(_saved.get("castaway_misses", 0))
		capsules.castaway_found = bool(_saved.get("castaway_found", false))
	waiting.get_returning().load_save(_saved.get("returning", []), types)
	var lines: Dictionary = _saved.get("lines", {})
	for planet: Planet in _planets:
		var line: Dictionary = lines.get(String(planet.name), {})
		var seen: Array[Passenger] = []
		for saved: Variant in line.get("seen", []):
			var passenger := Passenger.from_save(saved as Dictionary, types, by_name)
			if passenger:
				seen.append(passenger)
		waiting.restore(planet, seen, int(line.get("unseen", 0)))
		planet.found_abandoned = bool(line.get("found_abandoned", false))
	for saved: Variant in _saved.get("cabin", []):
		var passenger := Passenger.from_save(saved as Dictionary, types, by_name)
		if passenger:
			if Castaway.is_castaway(passenger):
				Castaway.dress(passenger, passenger.returning)
			if Vip.is_vip(passenger):
				Vip.dress(passenger)
			cabin.board(passenger)
	if vips:
		vips.load_save(_saved.get("vips", {}))
	var saved_goals: Array = _saved.get("goals", [])
	var tracked := goals.get_goals()
	for i: int in mini(saved_goals.size(), tracked.size()):
		tracked[i].load_save(saved_goals[i] as Dictionary)
	if quest_giver:
		# A save from before tours were kept apart has one quest.
		var quests: Array = _saved.get("quests", [_saved.get("quest", {})])
		quest_giver.load_save(quests, cabin.get_passengers(), by_name)


func _get_planets_by_name() -> Dictionary[String, Planet]:
	var by_name: Dictionary[String, Planet] = {}
	for planet: Planet in _planets:
		by_name[String(planet.name)] = planet
	return by_name


# Every passenger type that turns up, by its resource path.
func _get_types_by_path() -> Dictionary[String, PassengerType]:
	var types: Dictionary[String, PassengerType] = {}
	for type: PassengerType in waiting.types + [waiting.business, Vip.TYPE]:
		if type:
			types[type.resource_path] = type
	return types


# [param key] as saved, with an older save's planet name turned into its tree's file name.
func _upgrade_key(key: String) -> String:
	var tree := key.get_slice("/", 0)
	if PLANET_TREES.has(tree):
		return PLANET_TREES[tree] + key.trim_prefix(tree)
	return key


# Every upgrade in every research tree, by its tree's file name and its place in the
# tree, which stay the same when the tree's file is edited or exported.
func _get_upgrades_by_key() -> Dictionary[String, Upgrade]:
	var upgrades: Dictionary[String, Upgrade] = {}
	for tree: ResearchTree in research_lab.trees:
		var name := tree.resource_path.get_file().get_basename()
		for upgrade: Upgrade in tree.upgrades:
			upgrades["%s/%d/%d" % [name, upgrade.tier, upgrade.column]] = upgrade
	return upgrades
