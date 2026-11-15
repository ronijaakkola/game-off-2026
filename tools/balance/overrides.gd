extends RefCounted
## Where a balance run starts, and the numbers it sets without touching a file, from the
## config's "overrides":
## "waiting.max_per_planet", "commuter.slack", "business.fare_multiplier",
## "snack.min_interval", "drink.max_interval", "cabin.seats", "tank.burn_per_unit", and
## the drive's "bus.charge_time", "bus.cool_time" and "bus.warm_boost", and
## "temperature.comfortable_temperature": any exported number on those resources and nodes.
## "upgrade_credits" / "upgrade_points", a list of costs by tree row, and "upgrade_cost",
## one upgrade's own {title: [credits, points]}. "start_with" set to "all" starts on a bus
## with every built upgrade researched, and to a list of titles, with those.
## "fuel_price_scale" multiplies every planet's fuel price. "open_stages" is how many
## research stages are open (1 to 3).
## "after_tutorial" (true unless set false) starts where a new run starts once the
## tutorial is over: docked at its home planet (Terra) facing its destination, with
## Fuel tank 1 researched and the tank as the flight home left it. Its one ride and
## upgrade pay for each other, so the credits and points start at none either way. False
## starts as the scene does on its own: docked at Ember, nothing researched, a full tank.

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
	bus.start_planet = tutorial.home
	var toward := tutorial.destination.get_orbit_point()
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
		}
	)
	for planet: Planet in planets:
		planet.fuel_price *= float(_overrides.get("fuel_price_scale", 1.0))
	for i: int in int(_overrides.get("open_stages", 1)) - 1:
		lab.get_research().open_next_stage()
	# The flight home burned this much of the tank before Fuel tank 1 added its empty room.
	var fuel_left := tank.capacity * (1.0 - TutorialRules.TRIP_FUEL)
	var start_with: Variant = _overrides.get("start_with", [])
	for tree: ResearchTree in lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			var built := not upgrade.description.contains("NOT IMPLEMENTED")
			var named: bool = start_with is Array and upgrade.title in start_with
			var all: bool = start_with is String and start_with == "all" and built
			var tutorial := _after_tutorial() and upgrade.title == TutorialRules.FUEL_TANK
			if named or all or tutorial:
				lab.get_research().research(upgrade)
			_set_cost(upgrade)
	if _after_tutorial():
		tank.fuel = minf(fuel_left, tank.capacity)


func _after_tutorial() -> bool:
	return bool(_overrides.get("after_tutorial", true))


func _set_cost(upgrade: Upgrade) -> void:
	var credits: Array = _overrides.get("upgrade_credits", [])
	if upgrade.tier < credits.size():
		upgrade.credits = int(credits[upgrade.tier])
	var own: Variant = (_overrides.get("upgrade_cost", {}) as Dictionary).get(upgrade.title)
	if own is Array:
		upgrade.credits = int(own[0])
		for race: Race.Type in upgrade.points:
			upgrade.points[race] = int(own[1])
	var points: Array = _overrides.get("upgrade_points", [])
	if upgrade.tier < points.size():
		for race: Race.Type in upgrade.points:
			upgrade.points[race] = int(points[upgrade.tier])


# Sets each "owner.member" override whose owner is among [param owners].
func _set_on(owners: Dictionary) -> void:
	for key: String in _overrides:
		var parts := key.split(".")
		if parts.size() == 2 and owners.has(parts[0]):
			(owners[parts[0]] as Object).set(parts[1], _overrides[key])
