class_name PassengerType
extends Resource
## A kind of passenger, such as a tourist or a business traveller: what they pay, how
## patient they are, what they ask for on the ride and what they do in between.

@export var display_name := "Passenger"
## Multiplies the trip's base fare.
@export_range(0.0, 5.0, 0.05) var fare_multiplier := 1.0
## Patience at boarding, as a multiple of the direct trip time.
@export_range(1.0, 5.0, 0.05) var patience_slack := 1.5
## What they ask for during a ride. Each need keeps its own timer.
@export var needs: Array[Need] = []
## What the card says they are doing while nothing is asked for.
@export var idle_lines: Array[String] = ["Looking at empty space"]
## Idle lines they show while asleep, with their eyes shut. Each comes up as often as any
## one idle line.
@export var sleep_lines: Array[String] = []
## The names a passenger of this type picks from.
@export var names: Array[String] = ["Passenger"]
