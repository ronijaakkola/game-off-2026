class_name RatingBand
extends RefCounted
## The bands of the player's recent rating ([method Ledger.get_recent_rating]), which set
## how many of the passengers who turn up are Business: more of them from each band up.
## Bands count from 0, the lowest.

## The recent rating each band above the lowest starts at.
const EDGES: Array[float] = [3.5, 4.25]
## The share of passengers who are Business, by band.
const BUSINESS_SHARE: Array[float] = [0.05, 0.25, 0.45]
## How many Business passengers one line holds at most, by band.
const BUSINESS_PER_LINE: Array[int] = [1, 2, 2]


## The band [param rating] is in.
static func of(rating: float) -> int:
	var band := 0
	for edge: float in EDGES:
		if rating >= edge:
			band += 1
	return band
