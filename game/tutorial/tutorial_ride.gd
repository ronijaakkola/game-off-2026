class_name TutorialRide
extends RefCounted
## The [Tutorial]'s one passenger on their ride from home to the destination: once on board
## they ask for nothing until halfway there, then for a snack ([constant SNACK]), and for
## nothing more once it is served. Getting off, they rate the ride, and their card fills its
## stars ([method get_stars_seconds]).

## What the passenger asks for, halfway to the destination.
const SNACK := preload("res://game/passengers/needs/snack.tres")
## How many times longer the passenger's needs wait once on board, and again once the snack
## is served: long past the end of it, so nothing else comes up.
const NO_NEEDS := 1000.0
## Seconds after the stars have filled on the passenger's card before the game pauses on
## them.
const STARS_BEAT := 0.2

## The passenger, once on board.
var passenger: Passenger
## The stars they rated the ride, once they got off.
var rating := 0

# How far the bus had to go as it left, and whether the passenger has asked for their
# snack.
var _leg := 0.0
var _asked := false


## [param boarded] is on board, and asks for nothing for now.
func board(boarded: Passenger) -> void:
	passenger = boarded
	passenger.delay_requests(NO_NEEDS)


## The bus leaves for the destination with [param distance] to go.
func leave(distance: float) -> void:
	_leg = distance


## Whether the passenger asks for their snack now, with [param distance] left: once,
## halfway there.
func asks_for_snack(distance: float) -> bool:
	if _asked or distance > _leg * 0.5:
		return false
	_asked = true
	passenger.ask_for(SNACK)
	return true


## Whether the snack has been served. Once it has, they ask for nothing more.
func is_served() -> bool:
	if passenger.request:
		return false
	passenger.delay_requests(NO_NEEDS)
	return true


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
