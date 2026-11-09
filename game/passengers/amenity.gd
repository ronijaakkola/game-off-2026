class_name Amenity
extends Resource
## Something on the bus that serves food by itself, such as a food dispenser: once a
## passenger asks for a snack or a drink ([member Need.food]), it fills the request over
## [member seconds], for up to [member capacity] passengers at a time, and anyone else
## asking waits for it to be free. The player can still serve by hand meanwhile, which adds
## to its speed. The [Cabin] has it on board while the bus has [member bus_trait], which an
## upgrade gives.

## The trait the bus needs for it to be on board.
@export var bus_trait := BusTraits.Type.FOOD_DISPENSER
## The card's line while it serves a passenger, with [code]%s[/code] for the need's
## [member Need.item]: "Getting %s from the dispenser".
@export var line := "Getting %s"
## The card's line while a passenger waits for it to be free.
@export var waiting_line := "Waiting"
## Seconds it takes to serve one request by itself.
@export_range(0.1, 60.0, 0.1) var seconds := 4.0
## How many passengers it serves at a time.
@export_range(1, 12) var capacity := 1


## The card's line while it serves [param need].
func get_line(need: Need) -> String:
	return line % need.item if line.contains("%s") else line
