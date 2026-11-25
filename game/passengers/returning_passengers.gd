class_name ReturningPassengers
extends RefCounted
## The passengers who may come back: each rated a ride five stars, and by a roll of the dice
## is remembered ([method remember]) as who they are, their name, type, race and look.
## After [constant AWAY_SECONDS] away, one of them may turn up in a line again
## ([method take]) as a returning passenger ([member Passenger.returning]), who pays more
## ([constant Payment.RETURNING]), rides [constant BONUS] happier and is likelier to call
## with a quest. They are gone from here once they turn up, so coming back again takes
## another five-star ride.


## Someone who may come back.
class Person:
	var name: String
	var type: PassengerType
	var race: Race.Type
	var look: AlienLook


## What a returning passenger adds to the happiness they settle at, all ride long.
const BONUS := 3.0
## How many are remembered at most. One more takes the place of the one away longest.
const MAX_REMEMBERED := 6
## Seconds someone stays away before they can turn up again, so nobody waits at the next
## planet moments after getting off.
const AWAY_SECONDS := 60.0

var _rng := RandomNumberGenerator.new()
# Those remembered, away longest first, and the seconds each still stays away.
var _people: Array[Person] = []
var _away: Dictionary[Person, float] = {}


## Makes every roll from here on follow from [param value]. The dice are its own, so a
## game where nobody comes back plays as one without it.
func seed_dice(value: int) -> void:
	_rng.seed = value


## Runs [param delta] seconds of everyone's time away.
func run(delta: float) -> void:
	for person: Person in _people:
		_away[person] = maxf(_away[person] - delta, 0.0)


## How many are remembered.
func count() -> int:
	return _people.size()


## [param passenger] got off. When they rate the ride five stars they are remembered, by
## [param chance] from 0 to 1. True when they are.
func remember(passenger: Passenger, chance: float) -> bool:
	if passenger.get_rating() < Passenger.MAX_STARS or _rng.randf() >= chance:
		return false
	var person := Person.new()
	person.name = passenger.name
	person.type = passenger.type
	person.race = passenger.race
	person.look = passenger.look
	_add(person, AWAY_SECONDS)
	return true


## Someone who comes back now, by [param chance] from 0 to 1, or null: the one away
## longest of those whose time away is over and whom [param fits] accepts, called with
## each [Person]. They are no longer remembered.
func take(chance: float, fits: Callable) -> Person:
	for person: Person in _people:
		if _away[person] > 0.0 or not fits.call(person):
			continue
		if _rng.randf() >= chance:
			return null
		_people.erase(person)
		_away.erase(person)
		return person
	return null


## Everyone remembered, for a save game, their type by its resource path. How long each
## still stays away isn't kept.
func to_save() -> Array[Dictionary]:
	var saved: Array[Dictionary] = []
	for person: Person in _people:
		(
			saved
			. append(
				{
					"name": person.name,
					"type": person.type.resource_path,
					"race": person.race,
					"look": person.look.to_save(person.race),
				}
			)
		)
	return saved


## Puts back who [method to_save] gave, each type found by its resource path in
## [param types], in place of anyone remembered. Nobody stays away any longer.
func load_save(saved: Array, types: Dictionary[String, PassengerType]) -> void:
	_people.clear()
	_away.clear()
	for entry: Variant in saved:
		var kept := entry as Dictionary
		var type: PassengerType = types.get(kept.get("type", ""))
		if not type:
			continue
		var person := Person.new()
		person.name = str(kept.get("name", ""))
		person.type = type
		person.race = int(kept.get("race", 0)) as Race.Type
		person.look = AlienLook.from_save(kept.get("look", {}), person.race)
		_add(person, 0.0)


func _add(person: Person, away: float) -> void:
	_people.append(person)
	_away[person] = away
	while _people.size() > MAX_REMEMBERED:
		_away.erase(_people.pop_front())
