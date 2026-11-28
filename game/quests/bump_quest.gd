class_name BumpQuest
extends HopQuest
## The [Castaway]'s quest in the star system VIPs call in ([VipCalls]): they are going
## nowhere, as on a hop ([HopQuest]), and want to be bumped off the bus by a VIP. A VIP
## picked up on a bus with too few seats free for them kicks passengers off to make room,
## and the castaway first ([Seating]), so the player fills the seats and then picks up a
## VIP ([BumpGoal]). What they say tells the player that VIPs do that, since nothing else
## does until it happens.

const BUMP_KIND := "bump"
## What it asks, in the transmission, the goal panel and the flag on their portrait.
const ASK := "Board a VIP with the bus full"
const BUMP_LINES: Array[String] = [
	(
		"Oh, hello. They say a VIP throws people off a full bus to fit in. I'd love that! "
		+ "Fill every seat, then pick one up?"
	),
	(
		"Ground control never bumped me for anyone famous. Pick up a VIP while the bus is "
		+ "full, would you? They kick someone off, and I'll go first."
	),
	(
		"A lift? How kind. VIPs won't squeeze in, you know: on a full bus, someone gets "
		+ "thrown out. Fill up, fetch one, and let it be me?"
	),
]
## What the [Castaway] says once the player has taken them on board before.
const BUMP_RETURNING_LINES: Array[String] = [
	(
		"Ah, it's you. New wish: thrown off by a celebrity. Fill the seats, pick up a VIP, "
		+ "and they'll kick me out first."
	),
	(
		"We must stop meeting like this. Pick up a VIP with the bus full? They throw "
		+ "someone off to fit in. Me, ideally."
	),
]


func plan(
	who: Passenger,
	_bus: FrameshiftBus,
	_planets: Array[Planet],
	_waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	passenger = who
	who.destination = null
	who.fare = 0.0
	who.ride = RideProgress.new(FOREVER, FOREVER, who.type.stop_tolerance)
	reward_credits = get_reward(HOP_REWARD_CREDITS)
	reward_research = get_reward(HOP_REWARD_RESEARCH)
	var lines := BUMP_RETURNING_LINES if who.returning else BUMP_LINES
	_line = lines[rng.randi_range(0, lines.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	passenger = who
	goal = BumpGoal.new(who)
	load_save(saved)
	return true


func get_kind() -> String:
	return BUMP_KIND


func get_ask() -> String:
	return ASK


func accept() -> void:
	goal = BumpGoal.new(passenger)


## The goal counts the seats free on [param cabin].
func begin(cabin: Cabin) -> void:
	(goal as BumpGoal).cabin = cabin


func to_save() -> Dictionary:
	var saved := super()
	saved.erase("spot")
	return saved
