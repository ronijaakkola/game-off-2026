class_name PassengerType
extends Resource
## A kind of passenger, such as a tourist or a business traveller: what they pay, how
## patient they are, what they ask for on the ride and what they do in between.

@export var display_name := "Passenger"
## The icons of the badges on their portrait wherever the player meets them, so a kind that
## asks more of the bus can be told apart. None for the ordinary kind.
@export var badges: Array[Texture2D] = []
## What the player reads about this kind under its name, with the pointer over a badge.
## Empty for no tooltip.
@export var description := ""
## Multiplies the trip's base fare.
@export_range(0.0, 5.0, 0.05) var fare_multiplier := 1.0
## How long they expect the ride to take, as a multiple of the direct trip time. Their
## timing only starts to cost happiness past it.
@export_range(1.0, 5.0, 0.05) var slack := 1.5
## What they ask for during a ride. Each need keeps its own timer.
@export var needs: Array[Need] = []
## Multiplies the time between a need's requests: under 1 they ask more often.
@export_range(0.1, 3.0, 0.05) var need_interval_scale := 1.0
## What the card says they are doing while nothing is asked for.
@export var idle_lines: Array[String] = ["Looking at empty space"]
## Idle lines they show while asleep, with their eyes shut. Each comes up as often as any
## one idle line.
@export var sleep_lines: Array[String] = []
## Idle lines they show while watching a show, on a bus with an entertainment system. Each
## comes up as often as any one idle line.
@export var watch_lines: Array[String] = []
## The names a passenger of this type picks from.
@export var names: Array[String] = ["Passenger"]
