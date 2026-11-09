class_name Need
extends Resource
## Something a passenger asks for during a ride, such as a snack, a drink or entertainment.
## While the request is open the passenger loses patience faster, until the player serves
## it or an [Amenity] on the bus does.

## What a passenger's portrait acts out while the need is served.
enum Action { NONE, EAT, DRINK, WATCH }

## Names the need, so an amenity can say which one it serves.
@export var id: StringName
## The card's line while the request is open.
@export var request_line := "Wants something"
## The serve button's text on the card.
@export var serve_label := "Serve"
## What their portrait acts out while it is served, by the player or an amenity.
@export var served_action := Action.NONE
## The card's line while the player's service lasts.
@export var served_line := "Enjoying it"
## Seconds the served activity lasts, before the passenger goes back to idling.
@export_range(0.0, 60.0, 0.5) var served_seconds := 5.0
## Seconds from boarding, or from the end of the last served activity, to the next
## request: a random value between these two.
@export_range(1.0, 600.0, 1.0) var min_interval := 20.0
@export_range(1.0, 600.0, 1.0) var max_interval := 40.0
## How many times faster patience runs down while the request is open.
@export_range(1.0, 10.0, 0.1) var unmet_drain := 3.0
