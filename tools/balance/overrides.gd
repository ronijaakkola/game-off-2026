extends RefCounted
## Where a balance run starts, and the numbers it sets without touching a file, from the
## config's "overrides":
## "waiting.max_per_planet", "commuter.slack", "business.fare_multiplier",
## "snack.min_interval", "drink.max_interval", "cabin.seats", "tank.burn_per_unit", and
## the drive's "bus.charge_time", "bus.quick_time" and "bus.warm_charge_time", and
## "temperature.comfortable_temperature" and "quests.done_happiness": any exported number on
## those resources and nodes.
## "upgrade_credits" / "upgrade_points", a list of costs by tree row, and "upgrade_cost",
## one upgrade's own {title: [credits, points]}. "start_with" set to "all" starts on a bus
## with every built upgrade researched, and to a list of titles, with those.
## "fuel_price_scale" multiplies every planet's fuel price. "open_stages" is how many
## research stages are open (1 to 3). "mechanic" set true has the mechanic's call open
## research as in play (calls.gd answers it), with "mechanic_deliveries" the deliveries at
## which it does; otherwise research is open from the start.
## "after_tutorial" (true unless set false) starts where a new run starts once the
## tutorial is over: docked at its destination (the Moon) facing home, on a full tank, with
## nothing researched and the credits and research point its one ride paid. False starts
## as the scene does on its own: docked at Ember, with nothing.

const COMMUTER := "res://game/passengers/types/commuter.tres"
const BUSINESS := "res://game/passengers/types/business.tres"
const SNACK := "res://game/passengers/needs/snack.tres"
const DRINK := "res://game/passengers/needs/drink.tres"

var _overrides: Dictionary
# The shared resources overrides were set on, kept so the scene loads these same ones.
var _resources: Dictionary[String, Resource] = {}


func _init(overrides: Dictionary) -> void:
	_overrides = overrides


## Numbers on the shared resources, set before the scene loads them.
func apply_to_resources() -> void:
	_resources = {
		"commuter": load(COMMUTER),
		"business": load(BUSINESS),
		"snack": load(SNACK),
		"drink": load(DRINK),
	}
	_set_on(_resources)


## Where the bus starts, set on [param system] before it is in the tree.
func apply_before_ready(system: SolarSystem) -> void:
	if not _after_tutorial():
		return
	var tutorial := system.get_node(^"%Tutorial") as Tutorial
	var bus := system.get_node(^"%Bus") as FrameshiftBus
	bus.start_planet = tutorial.destination
	var toward := -tutorial.destination.get_orbit_point()
	bus.start_direction = Vector3(toward.x, 0.0, toward.z).normalized()


## Numbers on the scene's nodes and the trees, set once [param system] is in, and what the
## tutorial leaves behind.
func apply_to_scene(system: SolarSystem, planets: Array[Planet]) -> void:
	var bus := system.get_node(^"%Bus") as FrameshiftBus
	var lab := system.get_node(^"%ResearchLab") as ResearchLab
	var tank := bus.get_fuel_tank()
	_set_on(
		{
			"waiting": system.get_node(^"%WaitingPassengers"),
			"cabin": system.get_node(^"%Cabin"),
			"tank": tank,
			"bus": bus,
			"temperature": bus.temperature,
			"quests": system.get_node(^"%QuestGiver"),
		}
	)
	for planet: Planet in planets:
		planet.fuel_price *= float(_overrides.get("fuel_price_scale", 1.0))
	var research := lab.get_research()
	var mechanic := system.get_node(^"%MechanicCall") as MechanicCall
	mechanic.enabled = bool(_overrides.get("mechanic", false))
	var deliveries: int = _overrides.get("mechanic_deliveries", mechanic.research_deliveries)
	mechanic.research_deliveries = deliveries
	if not mechanic.enabled:
		research.open()
	for i: int in int(_overrides.get("open_stages", 1)) - 1:
		research.open_next_stage()
	var start_with: Variant = _overrides.get("start_with", [])
	for tree: ResearchTree in lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			var built := not upgrade.description.contains("NOT IMPLEMENTED")
			var named: bool = start_with is Array and upgrade.title in start_with
			var all: bool = start_with is String and start_with == "all" and built
			if named or all:
				research.research(upgrade)
			_set_cost(upgrade)
	tank.fill()
	if _after_tutorial():
		system.get_ledger().earn(roundi(TutorialRules.FARE))
		system.get_ledger().earn_research()


func _after_tutorial() -> bool:
	return bool(_overrides.get("after_tutorial", true))


func _set_cost(upgrade: Upgrade) -> void:
	var credits: Array = _overrides.get("upgrade_credits", [])
	if upgrade.tier < credits.size():
		upgrade.credits = int(credits[upgrade.tier])
	var own: Variant = (_overrides.get("upgrade_cost", {}) as Dictionary).get(upgrade.title)
	if own is Array:
		upgrade.credits = int(own[0])
		upgrade.points = int(own[1])
	var points: Array = _overrides.get("upgrade_points", [])
	if upgrade.tier < points.size():
		upgrade.points = int(points[upgrade.tier])


# Sets each "owner.member" override whose owner is among [param owners].
func _set_on(owners: Dictionary) -> void:
	for key: String in _overrides:
		var parts := key.split(".")
		if parts.size() == 2 and owners.has(parts[0]):
			(owners[parts[0]] as Object).set(parts[1], _overrides[key])
