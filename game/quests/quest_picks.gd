class_name QuestPicks
extends RefCounted
## Which quests a passenger on board may ask for ([QuestGiver]), in the order the dice try
## them. Past the first star system a Business passenger asks for an errand, a photo stop
## or a warp, and now and then for a ride through the rocks or a sauna, by
## [constant BUSINESS_WEIGHTS]; anyone else asks for a fly past or an errand, as likely one
## as the other. In [constant BUSINESS_ONLY_LEVEL] only Business passengers ask. And which
## quest the castaway asks for out of their capsule ([method for_castaway]).

## The star system, counted from 0, where only Business passengers call.
const BUSINESS_ONLY_LEVEL := 1
## How likely a Business passenger past the first system is to ask for each kind of quest,
## against the others that suit: a ride through the rocks and a sauna are the rare ones.
const BUSINESS_WEIGHTS: Dictionary[String, float] = {
	ErrandQuest.KIND: 1.0,
	PhotoStopQuest.PHOTO_KIND: 1.0,
	WarpQuest.KIND: 1.0,
	RockRideQuest.KIND: 0.2,
	SaunaQuest.KIND: 0.2,
}


## The quests [param passenger] may ask for in star system [param level], counted from 0,
## in the order to try them: empty when they ask for none there. [param business] is the
## Business type, and [param field] the rocks a ride through them asks for.
static func for_passenger(
	passenger: Passenger,
	business: PassengerType,
	level: int,
	field: AsteroidField,
	rng: RandomNumberGenerator
) -> Array[Quest]:
	var is_business := passenger.type == business
	if level == BUSINESS_ONLY_LEVEL and not is_business:
		return []
	var kinds: Array[Quest] = [FlybyQuest.new(), ErrandQuest.new()]
	if rng.randf() < 0.5:
		kinds.reverse()
	if level > 0 and is_business:
		kinds = _business_kinds(field, rng)
	return kinds


# The quests a Business passenger past the first system can ask for, in the order the dice
# try them: each drawn by its weight among those left.
static func _business_kinds(field: AsteroidField, rng: RandomNumberGenerator) -> Array[Quest]:
	var rocks := RockRideQuest.new()
	rocks.field = field
	var left: Array[Quest] = [
		ErrandQuest.new(), PhotoStopQuest.new(), WarpQuest.new(), rocks, SaunaQuest.new()
	]
	var order: Array[Quest] = []
	while not left.is_empty():
		var total := 0.0
		for quest: Quest in left:
			total += BUSINESS_WEIGHTS[quest.get_kind()]
		var roll := rng.randf() * total
		var pick := left.size() - 1
		for i: int in left.size():
			roll -= BUSINESS_WEIGHTS[left[i].get_kind()]
			if roll < 0.0:
				pick = i
				break
		order.append(left[pick])
		left.remove_at(pick)
	return order


## The quest the castaway asks for in star system [param level], counted from 0: a hop in
## the first, a hop with a window in the second, to be bumped off by a VIP where VIPs call,
## and a rescue anywhere else.
static func for_castaway(level: int) -> Quest:
	if level == 0:
		return HopQuest.new()
	if level == 1:
		return WindowHopQuest.new()
	if level == VipCalls.LEVEL:
		return BumpQuest.new()
	return RescueQuest.new()
