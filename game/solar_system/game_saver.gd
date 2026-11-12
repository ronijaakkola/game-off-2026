class_name GameSaver
extends Node
## Keeps the run in the player's save game ([code]SaveGame[/code]) and puts a saved run
## back. Only a run the main menu started is saved or continued; a scene started any other
## way runs a new run and saves nothing.
## The run is saved at checkpoints: once something it keeps has changed and the bus waits
## at a planet with no stop under way. A new run saves at once, over any save. A continued
## run starts docked at the planet it was saved at, so quitting in flight loses only the
## flight. It keeps where each planet is on its orbit, the bus's planet and fuel, the
## [Ledger], the researched upgrades and open research stages, the passengers on board and
## in every line, the goals' progress and the quest under way. The course, the charge and
## what passengers were doing start afresh.
## Putting a run back comes in two steps, so the scene builds a continued run as it builds
## a new one: [method place_world] before anything in the scene is ready, then
## [method start] once it is, which applies the rest on top.

## A save from before research trees left their planets keys each upgrade by the planet its
## tree was at: the tree file each planet had then.
const PLANET_TREES: Dictionary[String, String] = {
	"Frost": "blue_tree",
	"Terra": "green_tree",
	"Giant": "orange_tree",
}

## The bus whose planet, fuel and stats are kept.
@export var bus: FrameshiftBus
## Who is on board.
@export var cabin: Cabin
@export var goals: GoalTracker
## Whose quest under way is kept.
@export var quest_giver: QuestGiver
## Which upgrades are researched, which stages are open, and every research tree.
@export var research_lab: ResearchLab

## Who waits at each planet. The parent sets it before [method start].
var waiting: WaitingPassengers

var _recording := false
var _continued := false
var _saved: Dictionary = {}
var _ledger: Ledger
var _planets: Array[Planet] = []
# Something kept changed since the last save.
var _dirty := false


func _process(_delta: float) -> void:
	if _recording and _dirty and bus.is_at_planet() and not cabin.is_stopping():
		_write()


## Takes the run the main menu started, if any. Continuing one, it puts [param planets]
## back on their orbits, the bus at its planet and [param ledger] as it was: call it before
## the scene is ready, so everything starts there and the HUD shows the saved values.
func place_world(planets: Array[Planet], ledger: Ledger) -> void:
	_planets = planets
	_ledger = ledger
	_recording = SaveGame.has_started_run()
	_saved = SaveGame.claim_run()
	_continued = not _saved.is_empty()
	if not _continued:
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


## Whether this run continues a save.
func is_continued() -> bool:
	return _continued


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
	if quest_giver:
		quest_giver.changed.connect(_on_changed)
	research_lab.get_research().researched.connect(_on_changed.unbind(1))
	research_lab.get_research().stage_opened.connect(_on_changed.unbind(1))
	_ledger.credits_earned.connect(_on_changed.unbind(1))
	_ledger.credits_spent.connect(_on_changed.unbind(1))
	_ledger.credits_set.connect(_on_changed)
	_ledger.research_earned.connect(_on_changed.unbind(2))
	_ledger.research_spent.connect(_on_changed.unbind(2))
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
		"ledger": _ledger.to_save(),
		"research": researched,
		"research_stages": research.get_open_stages(),
		"cabin": on_board,
		"lines": lines,
		"goals": progress,
		"quest": quest_giver.to_save(cabin.get_passengers()) if quest_giver else {},
	}
	SaveGame.write(run)


# Upgrades first, so the seats and the tank are the saved bus's before anyone boards or
# the fuel goes in.
func _restore() -> void:
	var upgrades := _get_upgrades_by_key()
	var research := research_lab.get_research()
	for key: Variant in _saved.get("research", []):
		var found := _upgrade_key(str(key))
		if upgrades.has(found):
			research.research(upgrades[found])
	for stage: int in range(1, int(_saved.get("research_stages", 1))):
		research.open_next_stage()
	var tank := bus.get_fuel_tank()
	tank.fuel = clampf(float(_saved.get("fuel", tank.capacity)), 0.0, tank.capacity)
	var by_name := _get_planets_by_name()
	var types := _get_types_by_path()
	var lines: Dictionary = _saved.get("lines", {})
	for planet: Planet in _planets:
		var line: Dictionary = lines.get(String(planet.name), {})
		var seen: Array[Passenger] = []
		for saved: Variant in line.get("seen", []):
			var passenger := Passenger.from_save(saved as Dictionary, types, by_name)
			if passenger:
				seen.append(passenger)
		waiting.restore(planet, seen, int(line.get("unseen", 0)))
	for saved: Variant in _saved.get("cabin", []):
		var passenger := Passenger.from_save(saved as Dictionary, types, by_name)
		if passenger:
			cabin.board(passenger)
	var saved_goals: Array = _saved.get("goals", [])
	var tracked := goals.get_goals()
	for i: int in mini(saved_goals.size(), tracked.size()):
		tracked[i].load_save(saved_goals[i] as Dictionary)
	if quest_giver:
		quest_giver.load_save(_saved.get("quest", {}), cabin.get_passengers())


func _get_planets_by_name() -> Dictionary[String, Planet]:
	var by_name: Dictionary[String, Planet] = {}
	for planet: Planet in _planets:
		by_name[String(planet.name)] = planet
	return by_name


# Every passenger type that turns up, by its resource path.
func _get_types_by_path() -> Dictionary[String, PassengerType]:
	var types: Dictionary[String, PassengerType] = {}
	for type: PassengerType in waiting.types + [waiting.business]:
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
