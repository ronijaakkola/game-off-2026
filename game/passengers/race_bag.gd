class_name RaceBag
extends RefCounted
## The races new passengers are dealt from: a bag holding [constant COPIES] of each,
## shuffled, so no race stays away for long, filled again once empty. A race asked for with
## [method deal_next] comes before the bag's.

## How many of each race go into the bag.
const COPIES := 2

var _rng: RandomNumberGenerator
var _bag: Array[Race.Type] = []
# Races to deal before the bag's, first first.
var _next: Array[Race.Type] = []


## A bag shuffled with [param rng], so a seeded run deals the same races.
func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Makes the next race dealt [param race], in place of one from the bag.
func deal_next(race: Race.Type) -> void:
	_next.append(race)


## The next race: one asked for with [method deal_next] first, then the bag's.
func deal() -> Race.Type:
	if not _next.is_empty():
		return _next.pop_front()
	if _bag.is_empty():
		for value: int in Race.Type.values():
			for i: int in COPIES:
				_bag.insert(_rng.randi_range(0, _bag.size()), value as Race.Type)
	return _bag.pop_back()
