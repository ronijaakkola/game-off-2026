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
## What the player reads about each band.
const ATTRACTS: Array[String] = [
	"Commuters, and a rare Business passenger.",
	"Commuters and some Business passengers.",
	"Commuters and many Business passengers.",
]
const NEXT_BRINGS := "more Business passengers"


## The band [param rating] is in.
static func of(rating: float) -> int:
	var band := 0
	for edge: float in EDGES:
		if rating >= edge:
			band += 1
	return band


## Who [param rating] attracts and what the next band brings, as the player reads it.
static func describe(rating: float) -> String:
	var band := of(rating)
	var text := "Your last rides attract:\n%s" % ATTRACTS[band]
	if band < EDGES.size():
		text += "\nFrom %s stars: %s." % [String.num(EDGES[band], 2), NEXT_BRINGS]
	return text
