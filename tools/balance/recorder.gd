extends RefCounted
## What a balance run measures: every delivery, how the player's hand was kept busy by
## requests, how full the seats were, and where the credits, research points and rating
## stood over time. `run.gd` feeds it; `tools/balance.py` reads what [method report] gives.

## Seconds between two rows of the time series.
const SAMPLE_SECONDS := 15.0

var deliveries: Array[Dictionary] = []
var series: Array[Dictionary] = []
var upgrades: Array[Dictionary] = []
## What happened since the last dock decision, for a player who decides turn by turn.
var news: Array[String] = []
var holds := 0
var hand_seconds := 0.0
var flight_seconds := 0.0
var docked_seconds := 0.0
var seat_seconds := 0.0
var capacity_seconds := 0.0
var fuel_credits := 0
var tows := 0
var kicks := 0
var docks := 0
## Dock decisions made, and over them how many waited there and how many seats left empty.
var lines := 0
var line_total := 0
var free_seats_total := 0
var requests := 0
var request_seconds := 0.0
var worst_request := 0.0
var earned := 0
var spent_on_research := 0
## The run's two goals: this many delivered, and this all-time average rating.
var deliveries_goal := SolarSystem.START_DELIVERIES
var rating_goal := SolarSystem.START_RATING
## When each goal was first met, and when both first held at once, in seconds, or -1.
var deliveries_goal_at := -1.0
var rating_goal_at := -1.0
var both_goals_at := -1.0

var _rides: Dictionary[Passenger, Dictionary] = {}
var _open_since: Dictionary[Passenger, float] = {}
var _until_sample := 0.0
var _time := 0.0


## [param passenger] took a seat with [param aboard] on board, them included.
func board(passenger: Passenger, aboard: int) -> void:
	_rides[passenger] = {"at": _time, "aboard": aboard, "stops": 0, "requests": 0}


## The bus docked at [param planet]: everyone on board who isn't getting off there has one
## more stop behind them.
func dock(planet: Planet, passengers: Array[Passenger]) -> void:
	docks += 1
	for passenger: Passenger in passengers:
		if passenger.destination != planet and _rides.has(passenger):
			_rides[passenger]["stops"] += 1


func deliver(passenger: Passenger, payout: int, ledger: Ledger) -> void:
	var ride: Dictionary = _rides.get(passenger, {"at": _time, "aboard": 0, "stops": 0})
	_rides.erase(passenger)
	_open_since.erase(passenger)
	earned += payout
	var row := {
		"t": snappedf(_time, 0.1),
		"type": passenger.type.display_name,
		"race": Race.Type.find_key(passenger.race),
		"to": passenger.destination.display_name,
		"fare": snappedf(passenger.fare, 0.1),
		"payout": payout,
		"happiness": snappedf(passenger.happiness, 0.1),
		"stars": passenger.get_rating(),
		"ride": snappedf(_time - float(ride["at"]), 0.1),
		"trip": snappedf(passenger.trip_seconds, 0.1),
		"expected": snappedf(passenger.expected_seconds, 0.1),
		"stops": ride["stops"],
		"aboard": ride["aboard"],
		"requests": ride.get("requests", 0),
	}
	deliveries.append(row)
	news.append(
		(
			"%s (%s) got off at %s: %d stars, paid %d of a %d fare"
			% [passenger.name, row["type"], row["to"], row["stars"], payout, roundi(passenger.fare)]
		)
	)
	var rated := ledger.get_average_rating() >= rating_goal
	if deliveries_goal_at < 0.0 and deliveries.size() >= deliveries_goal:
		deliveries_goal_at = _time
	if rating_goal_at < 0.0 and rated:
		rating_goal_at = _time
	if both_goals_at < 0.0 and rated and deliveries.size() >= deliveries_goal:
		both_goals_at = _time


func research(upgrade: Upgrade) -> void:
	spent_on_research += upgrade.credits
	upgrades.append({"t": snappedf(_time, 0.1), "title": upgrade.title, "tier": upgrade.tier})


## Runs [param delta] seconds: the requests open on board, the seats taken, and a row of
## the time series when one is due.
func tick(delta: float, bus: FrameshiftBus, cabin: Cabin, ledger: Ledger) -> void:
	_time += delta
	var passengers := cabin.get_passengers()
	if bus.state == FrameshiftBus.State.FLYING:
		flight_seconds += delta
		seat_seconds += passengers.size() * delta
		capacity_seconds += cabin.seats * delta
	elif bus.is_at_planet():
		docked_seconds += delta
	for passenger: Passenger in passengers:
		if passenger.request and not _open_since.has(passenger):
			_open_since[passenger] = _time
			requests += 1
			if _rides.has(passenger):
				_rides[passenger]["requests"] += 1
		elif not passenger.request and _open_since.has(passenger):
			var waited := _time - _open_since[passenger]
			request_seconds += waited
			worst_request = maxf(worst_request, waited)
			_open_since.erase(passenger)
	_until_sample -= delta
	if _until_sample <= 0.0:
		_until_sample += SAMPLE_SECONDS
		(
			series
			. append(
				{
					"t": snappedf(_time, 0.1),
					"credits": ledger.credits,
					"points": _points(ledger),
					"recent": snappedf(ledger.get_recent_rating(), 0.01),
					"average": snappedf(ledger.get_average_rating(), 0.01),
					"delivered": deliveries.size(),
					"upgrades": upgrades.size(),
					"aboard": passengers.size(),
					"seats": cabin.seats,
				}
			)
		)


## Everything measured, as plain data.
func report(ledger: Ledger) -> Dictionary:
	return {
		"seconds": snappedf(_time, 0.1),
		"credits": ledger.credits,
		"points": _points(ledger),
		"earned": earned,
		"spent_on_research": spent_on_research,
		"fuel_credits": fuel_credits,
		"average_rating": snappedf(ledger.get_average_rating(), 0.001),
		"recent_rating": snappedf(ledger.get_recent_rating(), 0.001),
		"holds": holds,
		"hand_seconds": snappedf(hand_seconds, 0.1),
		"flight_seconds": snappedf(flight_seconds, 0.1),
		"docked_seconds": snappedf(docked_seconds, 0.1),
		"seat_seconds": snappedf(seat_seconds, 0.1),
		"capacity_seconds": snappedf(capacity_seconds, 0.1),
		"requests": requests,
		"request_seconds": snappedf(request_seconds, 0.1),
		"worst_request": snappedf(worst_request, 0.1),
		"tows": tows,
		"kicks": kicks,
		"docks": docks,
		"waiting_at_dock": snappedf(line_total / maxf(lines, 1.0), 0.01),
		"empty_seats_leaving": snappedf(free_seats_total / maxf(lines, 1.0), 0.01),
		"points_earned": deliveries.size(),
		"deliveries_goal_at": snappedf(deliveries_goal_at, 0.1),
		"rating_goal_at": snappedf(rating_goal_at, 0.1),
		"both_goals_at": snappedf(both_goals_at, 0.1),
		"rating_goal": rating_goal,
		"deliveries": deliveries,
		"upgrades": upgrades,
		"series": series,
	}


func _points(ledger: Ledger) -> Dictionary:
	var points := {}
	for value: int in Race.Type.values():
		points[Race.Type.find_key(value)] = ledger.get_research(value as Race.Type)
	return points
