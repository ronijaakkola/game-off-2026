class_name Payment
extends RefCounted
## What a passenger pays on getting off, as a multiple of their fare, by the stars they rate
## the ride ([method Passenger.get_rating]). A poor ride costs the rating, never the fare:
## everyone pays the fare, and only a good ride pays more. A returning passenger
## ([member Passenger.returning]) pays more than anyone else would, good ride or not.

## What a ride of 4 stars pays, and one of 5.
const FOUR_STARS := 1.1
const FIVE_STARS := 1.2
## The fewest stars that pay more than the fare: a happy passenger's.
const TIP_FROM_STARS := 4.0
## What a returning passenger pays, as a multiple of what anyone else would for the same
## ride: on top of everything else.
const RETURNING := 1.1


## The multiple of the fare a ride of [param stars] pays. [param tip] adds to what a ride
## that pays more than the fare pays: the Tip jar's. A [param returning] passenger pays
## [constant RETURNING] times all of it, whatever the stars.
static func multiple(stars: float, tip := 0.0, returning := false) -> float:
	var loyalty := RETURNING if returning else 1.0
	if stars < TIP_FROM_STARS:
		return loyalty
	return ((FIVE_STARS if stars >= Passenger.MAX_STARS else FOUR_STARS) + tip) * loyalty
