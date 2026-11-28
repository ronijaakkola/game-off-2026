class_name Ledger
extends RefCounted
## What the player has earned and spent: their credits, their research points, and the
## ratings passengers gave. The solar system owns the one ledger
## ([method SolarSystem.get_ledger]); game code reads and changes these here, and the
## resource bar's counters only show them, animating each change as its signal comes.

## [param amount] credits came in, as a fare. The resource bar shows it as a gain that
## waits for its commit.
signal credits_earned(amount: int)
## [param amount] credits went out, as a bill. The resource bar shows it as a loss at once.
signal credits_spent(amount: int)
## [member credits] was set outright, as by a test. The resource bar shows it at once.
signal credits_set
## [param amount] research points came in.
signal research_earned(amount: int)
## [param amount] research points went out, as on researching an upgrade.
signal research_spent(amount: int)
## A passenger rated the ride [param stars], already counted in [method get_average_rating]
## and [method get_recent_rating].
signal rated(stars: float)

## The credits the player has. Setting it outright emits [signal credits_set]; earn and
## spend with [method earn] and [method spend].
## How many of the latest ratings [method get_recent_rating] is the mean of.
const RECENT_RATINGS := 10
## With [member complaints_box], a rating under this many stars isn't counted.
const COMPLAINTS_BOX_STARS := 3.0

var credits: int:
	get:
		return _credits
	set(value):
		_credits = value
		credits_set.emit()

## Whether the Bottomless complaints box takes the poor ratings: while it does, [method rate]
## counts none under [constant COMPLAINTS_BOX_STARS]. The bus's traits set it
## ([ResearchLab]), so it isn't saved.
var complaints_box := false

var _credits := 0
var _research := 0
var _rating_total := 0.0
var _rating_count := 0
var _recent: Array[float] = []


## Adds [param amount] credits, as a fare.
func earn(amount: int) -> void:
	_credits += amount
	credits_earned.emit(amount)


## Takes [param amount] credits off, as a bill. It doesn't stop at 0; the caller decides
## what the player can pay.
func spend(amount: int) -> void:
	_credits -= amount
	credits_spent.emit(amount)


## Adds [param amount] research points.
func earn_research(amount := 1) -> void:
	_research += amount
	research_earned.emit(amount)


## Takes [param amount] research points off. Like [method spend], it doesn't stop at 0;
## the caller decides what the player can pay.
func spend_research(amount: int) -> void:
	_research -= amount
	research_spent.emit(amount)


## How many research points the player has.
func get_research() -> int:
	return _research


## Counts a passenger's rating of [param stars], from 0 to [constant Passenger.MAX_STARS];
## one out of that range counts as the nearest end. With [member complaints_box], one under
## [constant COMPLAINTS_BOX_STARS] isn't counted at all, and [signal rated] doesn't come.
func rate(stars: float) -> void:
	var clamped := clampf(stars, 0.0, Passenger.MAX_STARS)
	if complaints_box and clamped < COMPLAINTS_BOX_STARS:
		return
	_rating_total += clamped
	_rating_count += 1
	_recent.append(clamped)
	if _recent.size() > RECENT_RATINGS:
		_recent.pop_front()
	rated.emit(clamped)


## The mean of every rating so far, from 0 to [constant Passenger.MAX_STARS]. 0 before the
## first; [method get_rating_count] tells the two apart.
func get_average_rating() -> float:
	return _rating_total / _rating_count if _rating_count > 0 else 0.0


## The mean of the last [constant RECENT_RATINGS] ratings, which is the rating the player is
## shown and what sets who turns up ([RatingBand]). 0 before the first.
func get_recent_rating() -> float:
	var total := 0.0
	for stars: float in _recent:
		total += stars
	return total / _recent.size() if not _recent.is_empty() else 0.0


## How many rides have been rated.
func get_rating_count() -> int:
	return _rating_count


## Everything in it, for a save game.
func to_save() -> Dictionary:
	return {
		"credits": _credits,
		"research": _research,
		"rating_total": _rating_total,
		"rating_count": _rating_count,
		"recent": _recent.duplicate(),
	}


## Puts back what [method to_save] gave, with no signals: load it before anything shows it.
func load_save(saved: Dictionary) -> void:
	_credits = int(saved.get("credits", 0))
	_research = count_research(saved.get("research", 0))
	_rating_total = float(saved.get("rating_total", 0.0))
	_rating_count = int(saved.get("rating_count", 0))
	_recent.clear()
	for stars: Variant in saved.get("recent", []):
		_recent.append(float(stars))


## A saved count of research points: a number, or, from a save made while each race had
## points of its own, every race's added up.
static func count_research(saved: Variant) -> int:
	if saved is Dictionary:
		var total := 0
		for amount: Variant in (saved as Dictionary).values():
			total += int(amount)
		return total
	return int(saved)
