extends RefCounted
## The scripted player of a balance run: what it decides at each dock (who to pick up,
## what to research, whether to refuel and where to fly next), from a policy. It reads the
## same state a turn-by-turn player is shown ([method describe]) and answers with the same
## kind of decision, so a bot and an agent play through one door.
## A decision is a Dictionary: "board" (ids of waiting passengers), "kick" (names on
## board), "research" (upgrade ids), "refuel" (bool) and "next" (a planet's name).

## Flying this many times the straight distance must fit in the tank, or the bot refuels:
## planets move, and the bus chases them.
const FUEL_MARGIN := 1.5

var policy: Dictionary
var _rng := RandomNumberGenerator.new()


func _init(with_policy: Dictionary, seed_value: int) -> void:
	policy = with_policy
	_rng.seed = seed_value


## Seconds from a request opening to the player's hand reaching it: the policy's reaction
## time, half to one and a half times it, and now and then a lapse on top.
func reaction() -> float:
	var seconds := float(policy.get("reaction", 1.5)) * _rng.randf_range(0.5, 1.5)
	if _rng.randf() < float(policy.get("miss_chance", 0.1)):
		seconds += _rng.randf_range(3.0, 6.0)
	return seconds


## What the bot does at the dock [param state] describes.
func decide(state: Dictionary) -> Dictionary:
	var research := _pick_research(state)
	var seats := int(state["free_seats"])
	for id: String in research:
		seats += _seats_from(state, id)
	var board := _pick_passengers(state, seats)
	var going: Array[String] = []
	for passenger: Dictionary in state["on_board"]:
		going.append(passenger["to"])
	for passenger: Dictionary in state["waiting"]:
		if passenger["id"] in board:
			going.append(passenger["to"])
	var next := _pick_next(state, going)
	var needed := _distance_to(state, next) * FUEL_MARGIN * float(state["fuel"]["burn_per_unit"])
	var low := float(state["fuel"]["fuel"]) < float(state["fuel"]["capacity"]) * 0.5
	return {
		"board": board,
		"research": research,
		"refuel": low or needed > float(state["fuel"]["fuel"]),
		"next": next,
	}


# Every upgrade researchable here that the policy wants and the credits and points pay
# for, cheapest first. "none" researches nothing; a list of titles researches only those.
func _pick_research(state: Dictionary) -> Array[String]:
	var picked: Array[String] = []
	var wanted: Variant = policy.get("research", "cheapest")
	if wanted is String and wanted == "none":
		return picked
	# The tank is filled before anything is researched, so its price is never research's.
	var kept := maxi(int(policy.get("keep_credits", 15)), int(state["fuel"]["fill_costs"]))
	var credits := int(state["credits"]) - kept
	var points: Dictionary = (state["points"] as Dictionary).duplicate()
	var done: Array[String] = []
	var open: Array = (state["upgrades"] as Array).filter(
		func(upgrade: Dictionary) -> bool: return upgrade["here"]
	)
	open.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["credits"]) < int(b["credits"])
	)
	var found := true
	while found:
		found = false
		for upgrade: Dictionary in open:
			if upgrade["state"] == "researched" or upgrade["id"] in picked:
				continue
			if wanted is Array and upgrade["title"] not in wanted:
				continue
			if upgrade["not_built"] and not policy.get("research_not_built", false):
				continue
			# One researched path to it is enough.
			var ready: bool = (upgrade["requires"] as Array).is_empty()
			for needs: String in upgrade["requires"]:
				if needs in done or _is_researched(state, needs):
					ready = true
			var cost: Dictionary = upgrade["points"]
			for race: String in cost:
				if int(points.get(race, 0)) < int(cost[race]):
					ready = false
			if not ready or credits < int(upgrade["credits"]):
				continue
			credits -= int(upgrade["credits"])
			for race: String in cost:
				points[race] = int(points[race]) - int(cost[race])
			picked.append(upgrade["id"])
			done.append(upgrade["id"])
			found = true
	return picked


func _is_researched(state: Dictionary, id: String) -> bool:
	for upgrade: Dictionary in state["upgrades"]:
		if upgrade["id"] == id:
			return upgrade["state"] == "researched"
	return false


func _seats_from(state: Dictionary, id: String) -> int:
	for upgrade: Dictionary in state["upgrades"]:
		if upgrade["id"] == id:
			return int(upgrade["seats"])
	return 0


# "all" takes everyone who fits, longest waiting first, as the dock panel's button does.
# "smart" takes those going where someone on board already goes first, then the nearest
# destinations, and never to more than max_destinations planets at once. "business" set
# to "avoid" leaves Business passengers behind, and "prefer" takes them first.
func _pick_passengers(state: Dictionary, seats: int) -> Array[String]:
	var picked: Array[String] = []
	var line: Array = (state["waiting"] as Array).duplicate()
	var business := str(policy.get("business", "any"))
	if business == "avoid":
		line = line.filter(func(p: Dictionary) -> bool: return p["type"] != "Business")
	if str(policy.get("board", "smart")) == "all":
		for passenger: Dictionary in line:
			if picked.size() < seats:
				picked.append(passenger["id"])
		return picked
	var going: Array[String] = []
	for passenger: Dictionary in state["on_board"]:
		if passenger["to"] not in going:
			going.append(passenger["to"])
	var most := int(policy.get("max_destinations", 2))
	while picked.size() < seats:
		var best: Dictionary = {}
		var best_score := INF
		for passenger: Dictionary in line:
			if passenger["id"] in picked:
				continue
			var known: bool = passenger["to"] in going
			if not known and going.size() >= most:
				continue
			var score := 0.0 if known else 10.0 + float(passenger["distance"])
			if business == "prefer" and passenger["type"] == "Business":
				score -= 100.0
			if score < best_score:
				best = passenger
				best_score = score
		if best.is_empty():
			break
		picked.append(best["id"])
		if best["to"] not in going:
			going.append(best["to"])
	return picked


# The nearest of the planets someone is going to, or with nobody on board, the nearest
# planet of all.
func _pick_next(state: Dictionary, going: Array[String]) -> String:
	var next := ""
	var nearest := INF
	for planet: Dictionary in state["planets"]:
		if planet["here"] or (not going.is_empty() and planet["name"] not in going):
			continue
		if float(planet["distance"]) < nearest:
			next = planet["name"]
			nearest = float(planet["distance"])
	return next


func _distance_to(state: Dictionary, planet_name: String) -> float:
	for planet: Dictionary in state["planets"]:
		if planet["name"] == planet_name:
			return float(planet["distance"])
	return 0.0
