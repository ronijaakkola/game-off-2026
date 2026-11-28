class_name DestinationOdds
## Where a new passenger is going, rolled among the planets they could go to: likelier
## where someone already in their line is going, likelier still where someone on board is,
## and never where [constant MAX_SAME_DESTINATION] of the line already go, unless that
## leaves nowhere.

## How many in one line go to the same planet at most, so a line always holds a choice.
const MAX_SAME_DESTINATION := 2


## One of [param planets], rolled with [param rng]: [param in_line_weight] times likelier
## for each planet someone in [param line] is going to, and [param aboard_weight] times for
## each in [param aboard]. Null when [param planets] is empty.
static func pick(
	rng: RandomNumberGenerator,
	planets: Array,
	line: Array,
	in_line_weight: float,
	aboard: Array[Planet],
	aboard_weight: float
) -> Planet:
	if planets.is_empty():
		return null
	var weights := PackedFloat32Array()
	var total := 0.0
	for planet: Planet in planets:
		var same := line.filter(func(p: Passenger) -> bool: return p.destination == planet).size()
		var weight := 1.0
		if same >= MAX_SAME_DESTINATION:
			weight = 0.0
		elif same > 0:
			weight *= in_line_weight
		if planet in aboard:
			weight *= aboard_weight
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return planets[rng.randi_range(0, planets.size() - 1)]
	return planets[rng.rand_weighted(weights)]
