class_name TutorialRide
extends RefCounted
## The [Tutorial]'s one passenger on their ride from home to the destination: once on board
## they ask for nothing, as requests come later in the run. Getting off, they rate the ride,
## and their card fills its stars ([method get_stars_seconds]).

## How many times longer the passenger's needs wait once on board: long past the end of it,
## so nothing comes up.
const NO_NEEDS := 1000.0
## Seconds after the stars have filled on the passenger's card before the game pauses on
## them.
const STARS_BEAT := 0.2

## The passenger, once on board.
var passenger: Passenger
## The stars they rated the ride, once they got off.
var rating := 0


## [param boarded] is on board, and asks for nothing.
func board(boarded: Passenger) -> void:
	passenger = boarded
	passenger.delay_requests(NO_NEEDS)


## The passenger gets off and rates the ride.
func get_off() -> void:
	rating = roundi(passenger.get_rating())


## Seconds from their card starting to show the rating until its stars have filled, and a
## beat.
func get_stars_seconds() -> float:
	var fill := rating * PassengerCard.STAR_FILL_SECONDS
	return PassengerCard.SWAP_STAGGER + PassengerCard.SWAP_SECONDS + fill + STARS_BEAT


## The rating in words, for a guide card: "4 stars".
func describe_rating() -> String:
	return "%d star%s" % [rating, "" if rating == 1 else "s"]
