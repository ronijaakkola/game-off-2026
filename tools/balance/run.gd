extends Node
## Plays the real solar system headless, at whatever speed the machine manages, with a
## seeded dice and a scripted player, and writes what happened as JSON: the balance run
## behind `tools/balance.py`. The player decides only at docks; in flight a hand model
## serves requests one at a time, each after a reaction time.
## Run by `tools/balance.py` as the scene `run.tscn`, with the path of a config file after `--`:
## "seed", "minutes", "out", "policy" (player.gd), "overrides" (below), and for a
## turn-by-turn player "decisions" (the list given so far) and "state_out" (where the
## state to decide on is written when the list runs out).
## Overrides set exported numbers without touching a file: "waiting.max_per_planet",
## "commuter.slack", "business.fare_multiplier", "snack.min_interval",
## "drink.max_interval", "cabin.seats", "tank.burn_per_unit", "bus.charge_time", and
## "upgrade_credits" / "upgrade_points", a list of costs by tree row. "start_with" set to
## "all" starts on a bus with every built upgrade researched, and to a list of titles, with
## those. "open_stages" is how many research stages are open (1 to 3), and "rating_goal"
## and "deliveries_goal" are the goals the run is measured against.

const SCENE := "res://game/solar_system/solar_system.tscn"
const COMMUTER := "res://game/passengers/types/commuter.tres"
const BUSINESS := "res://game/passengers/types/business.tres"
const SNACK := "res://game/passengers/needs/snack.tres"
const DRINK := "res://game/passengers/needs/drink.tres"
const Recorder := preload("res://tools/balance/recorder.gd")
const Player := preload("res://tools/balance/player.gd")
## Seconds the hand takes to move from one serve button to the next.
const HAND_SWITCH := 0.3
## Seconds a player takes to ask for a tow once the bus has stopped.
const TOW_THINK := 3.0

var _config: Dictionary
var _recorder := Recorder.new()
var _player: Player
var _system: SolarSystem
var _bus: FrameshiftBus
var _cabin: Cabin
var _waiting: WaitingPassengers
var _lab: ResearchLab
var _ledger: Ledger
var _planets: Array[Planet] = []
var _time := 0.0
var _decided := false
var _think_left := 0.0
var _decision_count := 0
var _tow_in := -1.0
var _tow_notice: Notice
# The hand model: who it serves, when it is free again, and when it notices each request.
var _hand: Passenger
var _hand_free_at := 0.0
var _noticed_at: Dictionary[Passenger, float] = {}
var _ids: Dictionary[String, Passenger] = {}
# The shared resources overrides were set on, kept so the scene loads these same ones.
var _resources: Dictionary[String, Resource] = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var text := FileAccess.get_file_as_string(args[0]) if not args.is_empty() else ""
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		printerr("balance run: no config")
		get_tree().quit(2)
		return
	_config = parsed
	_apply_resource_overrides()
	_system = (load(SCENE) as PackedScene).instantiate() as SolarSystem
	add_child(_system)
	_bus = _system.get_node(^"%Bus") as FrameshiftBus
	_cabin = _system.get_node(^"%Cabin") as Cabin
	_waiting = _system.get_node(^"%WaitingPassengers") as WaitingPassengers
	_lab = _system.get_node(^"%ResearchLab") as ResearchLab
	# Nobody calls with a quest: the scripted player decides only at a dock, so it could
	# neither answer a call nor reroute for one.
	(_system.get_node(^"%QuestGiver") as QuestGiver).enabled = false
	_ledger = _system.get_ledger()
	_collect_planets(_system)
	var overrides: Dictionary = _config.get("overrides", {})
	_recorder.rating_goal = float(overrides.get("rating_goal", SolarSystem.START_RATING))
	_recorder.deliveries_goal = int(overrides.get("deliveries_goal", SolarSystem.START_DELIVERIES))
	_apply_node_overrides()
	# The same dice for the same seed: the lines start over with it.
	_waiting.seed_dice(int(_config.get("seed", 1)))
	_waiting.start(_planets, _bus.get_docked_planet(), _ledger)
	_player = Player.new(_config.get("policy", {}), int(_config.get("seed", 1)) + 7919)
	_think_left = float(_player.policy.get("dock_think", 3.0))
	_bus.docked.connect(_on_docked)
	_bus.ran_out_of_fuel.connect(_on_ran_out_of_fuel)
	_cabin.boarded.connect(_on_boarded)
	_cabin.delivered.connect(_on_delivered)
	_cabin.kicked.connect(func(_passenger: Passenger) -> void: _recorder.kicks += 1)
	_lab.get_research().researched.connect(_recorder.research)


func _process(delta: float) -> void:
	if not _system:
		return
	_time += delta
	_recorder.tick(delta, _bus, _cabin, _ledger)
	if _time >= float(_config.get("minutes", 15.0)) * 60.0:
		_finish(true)
		return
	if _tow_in >= 0.0:
		_tow_in -= delta
		if _tow_in < 0.0 and is_instance_valid(_tow_notice):
			_tow_notice.action_pressed.emit()
	if _bus.is_at_planet():
		_at_dock(delta)
	else:
		_decided = false
		_serve(delta)


func _at_dock(delta: float) -> void:
	_let_go()
	if _decided:
		_bus.frameshift_held = not _bus.get_route_stops().is_empty()
		return
	if _cabin.is_stopping():
		return
	_think_left -= delta
	if _think_left > 0.0:
		return
	var state := _describe()
	_recorder.lines += 1
	_recorder.line_total += (state["waiting"] as Array).size()
	var decision: Dictionary
	var given: Variant = _config.get("decisions")
	if given is Array:
		if _decision_count >= (given as Array).size():
			_write(str(_config["state_out"]), state)
			get_tree().quit(0)
			_system = null
			return
		decision = given[_decision_count]
	else:
		decision = _player.decide(state)
	_decision_count += 1
	_recorder.news.clear()
	if not _apply(decision):
		# Nothing was plotted, so the bus would sit here until the run's time is up.
		printerr('balance run: "next" must be another planet, not "%s"' % decision.get("next"))
		get_tree().quit(3)
		_system = null
		return
	_recorder.free_seats_total += _cabin.get_free_seats()
	_decided = true


# False when the decision names nowhere to fly to, and nothing of it was done.
func _apply(decision: Dictionary) -> bool:
	var next := _planet(str(decision.get("next", "")))
	var planet := _bus.get_docked_planet()
	if not next or next == planet:
		return false
	for passenger: Passenger in _cabin.get_passengers():
		if passenger.name in decision.get("kick", []):
			_cabin.kick(passenger)
	if decision.get("refuel", false):
		_refuel(planet)
	for id: String in decision.get("research", []):
		var upgrade := _upgrade(id)
		if upgrade and planet.has_lab:
			_lab.research(upgrade)
	var panel := _system.get_node(^"%DockPanel") as DockPanel
	for id: String in decision.get("board", []):
		if _ids.has(id):
			panel.board_pressed.emit(_ids[id])
	_bus.plot_course(RouteStop.at_planet(next))
	return true


# A full tank at the planet's price, or as much as the credits buy: what holding the fuel
# button until it stops comes to.
func _refuel(planet: Planet) -> void:
	var tank := _bus.get_fuel_tank()
	if not planet.sells_fuel or planet.fuel_price <= 0.0:
		return
	var amount := minf(tank.capacity - tank.fuel, maxi(_ledger.credits, 0) / planet.fuel_price)
	var cost := floori(amount * planet.fuel_price)
	if cost <= 0:
		return
	tank.refuel(amount)
	_ledger.spend(cost)
	_recorder.fuel_credits += cost


# One hand: it serves the request noticed first, holds until it is served, then moves on.
func _serve(delta: float) -> void:
	var passengers := _cabin.get_passengers()
	for passenger: Passenger in passengers:
		if passenger.request and not _noticed_at.has(passenger):
			_noticed_at[passenger] = _time + _player.reaction()
		elif not passenger.request:
			_noticed_at.erase(passenger)
	if _hand and (not _hand.request or _hand not in passengers):
		_let_go()
	if not _hand and _time >= _hand_free_at:
		var first := INF
		for passenger: Passenger in passengers:
			var at: float = _noticed_at.get(passenger, INF)
			if at <= _time and at < first:
				_hand = passenger
				first = at
		if _hand:
			_cabin.hold_serve(_hand, true)
			_recorder.holds += 1
	if _hand:
		_recorder.hand_seconds += delta


func _let_go() -> void:
	if not _hand:
		return
	_cabin.hold_serve(_hand, false)
	_hand = null
	_hand_free_at = _time + HAND_SWITCH


# What a player sees at the dock: the bus, who is on board, who waits here, how far each
# planet is, and every tree.
func _describe() -> Dictionary:
	var here := _bus.get_docked_planet()
	var tank := _bus.get_fuel_tank()
	var from := here.get_body_global_position()
	_ids.clear()
	var waiting: Array[Dictionary] = []
	for passenger: Passenger in _waiting.get_waiting(here):
		var id := "w%d" % (waiting.size() + 1)
		_ids[id] = passenger
		var row := _passenger_row(passenger)
		row["id"] = id
		row["distance"] = snappedf(
			from.distance_to(passenger.destination.get_body_global_position()), 0.1
		)
		waiting.append(row)
	var on_board: Array[Dictionary] = []
	for passenger: Passenger in _cabin.get_passengers():
		var row := _passenger_row(passenger)
		row["happiness"] = roundi(passenger.happiness)
		row["stars_now"] = passenger.get_rating()
		row["pays_now"] = passenger.get_payout()
		on_board.append(row)
	var planets: Array[Dictionary] = []
	var markers := _bus.get_stats().get_traits().has(BusTraits.Type.WAITING_MARKERS)
	for planet: Planet in _planets:
		var distance := from.distance_to(planet.get_body_global_position())
		var row := {
			"name": planet.display_name,
			"here": planet == here,
			"distance": snappedf(distance, 0.1),
			"flight_seconds": roundi(_bus.charge_time + distance / _bus.max_speed + 2.0),
			"full_tank_costs": ceili(tank.capacity * planet.fuel_price),
			"research": planet.has_lab,
		}
		if markers:
			row["waiting"] = _waiting.count_at(planet)
		planets.append(row)
	return {
		"decision": _decision_count + 1,
		"time": roundi(_time),
		"ends_at": roundi(float(_config.get("minutes", 15.0)) * 60.0),
		"planet": here.display_name,
		"credits": _ledger.credits,
		"points": _recorder.report(_ledger)["points"],
		"rating": snappedf(_ledger.get_recent_rating(), 0.01),
		"average_rating": snappedf(_ledger.get_average_rating(), 0.01),
		"delivered": _recorder.deliveries.size(),
		"fuel":
		{
			"fuel": roundi(tank.fuel),
			"capacity": roundi(tank.capacity),
			"burn_per_unit": tank.burn_per_unit,
			"range": snappedf(tank.fuel / tank.burn_per_unit, 0.1),
			"fill_costs": ceili((tank.capacity - tank.fuel) * here.fuel_price),
		},
		"seats": _cabin.seats,
		"free_seats": _cabin.get_free_seats(),
		"on_board": on_board,
		"waiting": waiting,
		"planets": planets,
		"upgrades": _upgrade_rows(here),
		"news": _recorder.news.duplicate(),
	}


func _passenger_row(passenger: Passenger) -> Dictionary:
	return {
		"name": passenger.name,
		"type": passenger.type.display_name,
		"race": Race.Type.find_key(passenger.race),
		"to": passenger.destination.display_name,
		"fare": roundi(passenger.fare),
		"trip_seconds": roundi(passenger.trip_seconds),
		"expected_seconds": roundi(passenger.expected_seconds),
	}


func _upgrade_rows(here: Planet) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var research := _lab.get_research()
	for tree: ResearchTree in _lab.trees:
		for i: int in tree.upgrades.size():
			var upgrade := tree.upgrades[i]
			var state := research.get_state(upgrade, _ledger.credits, _ledger.get_all_research())
			if state == Research.State.HIDDEN or state == Research.State.NEEDS_PROMOTION:
				continue
			var points := {}
			for race: Race.Type in upgrade.points:
				points[Race.Type.find_key(race)] = upgrade.points[race]
			var seats := 0
			for modifier: StatModifier in upgrade.modifiers:
				if modifier.stat == BusStats.Type.SEATS:
					seats += roundi(modifier.amount)
			var requires: Array[String] = []
			for needs: Resource in upgrade.requires:
				requires.append("%s#%d" % [tree.title, tree.upgrades.find(needs)])
			(
				rows
				. append(
					{
						"id": "%s#%d" % [tree.title, i],
						"tree": tree.title,
						"here": here.has_lab,
						"title": upgrade.title,
						"does": upgrade.description,
						"not_built": upgrade.description.contains("NOT IMPLEMENTED"),
						"credits": upgrade.credits,
						"points": points,
						"requires": requires,
						"seats": seats,
						"state": (Research.State.find_key(state) as String).to_lower(),
					}
				)
			)
	return rows


func _upgrade(id: String) -> Upgrade:
	var parts := id.split("#")
	if parts.size() != 2:
		return null
	for tree: ResearchTree in _lab.trees:
		if tree.title == parts[0]:
			var index := int(parts[1])
			return tree.upgrades[index] if index >= 0 and index < tree.upgrades.size() else null
	return null


func _collect_planets(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Planet:
			_planets.append(child as Planet)
		_collect_planets(child)


func _planet(planet_name: String) -> Planet:
	for planet: Planet in _planets:
		if planet.display_name.to_lower() == planet_name.to_lower():
			return planet
	return null


func _finish(done: bool) -> void:
	var report := _recorder.report(_ledger)
	report["done"] = done
	report["seed"] = _config.get("seed", 1)
	report["decisions_made"] = _decision_count
	report["seats"] = _cabin.seats
	_write(str(_config.get("out", "")), report)
	if _config.has("state_out"):
		_write(str(_config["state_out"]), {"done": true})
	get_tree().quit(0)
	_system = null


func _write(path: String, data: Dictionary) -> void:
	if path.is_empty():
		print(JSON.stringify(data))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _on_docked(planet: Planet) -> void:
	_think_left = float(_player.policy.get("dock_think", 3.0))
	_recorder.dock(planet, _cabin.get_passengers())


func _on_boarded(passenger: Passenger) -> void:
	_recorder.board(passenger, _cabin.get_passengers().size())


func _on_delivered(passenger: Passenger, payout: int) -> void:
	_recorder.deliver(passenger, payout, _ledger)


func _on_ran_out_of_fuel() -> void:
	_recorder.tows += 1
	_recorder.news.append("Ran out of fuel and had to be towed for %d" % TowDispatch.TOW_FEE)
	_tow_in = TOW_THINK
	# The system offered the tow just before this: its notice is the newest.
	var notices := (_system.get_node(^"%Notices") as NoticeStack).get_notices()
	_tow_notice = notices.back() if not notices.is_empty() else null


# Numbers on the shared resources, set before the scene loads them.
func _apply_resource_overrides() -> void:
	_resources = {
		"commuter": load(COMMUTER),
		"business": load(BUSINESS),
		"snack": load(SNACK),
		"drink": load(DRINK),
	}
	var overrides: Dictionary = _config.get("overrides", {})
	for key: String in overrides:
		var parts := key.split(".")
		if parts.size() == 2 and _resources.has(parts[0]):
			_resources[parts[0]].set(parts[1], overrides[key])


# Numbers on the scene's nodes and the trees, set once the scene is in.
func _apply_node_overrides() -> void:
	var nodes := {
		"waiting": _waiting,
		"cabin": _cabin,
		"tank": _bus.get_fuel_tank(),
		"bus": _bus,
	}
	var overrides: Dictionary = _config.get("overrides", {})
	for key: String in overrides:
		var parts := key.split(".")
		if parts.size() == 2 and nodes.has(parts[0]):
			(nodes[parts[0]] as Node).set(parts[1], overrides[key])
	for i: int in int(overrides.get("open_stages", 1)) - 1:
		_lab.get_research().open_next_stage()
	var start_with: Variant = overrides.get("start_with", [])
	for tree: ResearchTree in _lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			var built := not upgrade.description.contains("NOT IMPLEMENTED")
			var named: bool = start_with is Array and upgrade.title in start_with
			if named or (start_with is String and start_with == "all" and built):
				_lab.get_research().research(upgrade)
			var credits: Array = overrides.get("upgrade_credits", [])
			if upgrade.tier < credits.size():
				upgrade.credits = int(credits[upgrade.tier])
			var points: Array = overrides.get("upgrade_points", [])
			if upgrade.tier < points.size():
				for race: Race.Type in upgrade.points:
					upgrade.points[race] = int(points[upgrade.tier])
