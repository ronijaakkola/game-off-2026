class_name Amenity
extends Resource
## Something on the bus that serves a [Need] by itself, such as a food dispenser: a request
## for that need is served the moment it opens, so the player doesn't have to. Upgrades add
## amenities to the [Cabin].

## The [member Need.id] it serves.
@export var need: StringName
## The card's line while the passenger uses it.
@export var line := "Using the amenity"
## Seconds the passenger spends using it.
@export_range(0.0, 60.0, 0.5) var seconds := 5.0
