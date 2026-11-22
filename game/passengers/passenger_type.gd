class_name PassengerType
extends Resource
## A kind of passenger, such as a tourist or a business traveller: what they pay, how
## patient they are, what they ask for on the ride and what they do in between.

@export var display_name := "Passenger"
## The icons of the badges on their portrait wherever the player meets them, so a kind that
## asks more of the bus can be told apart. None for the ordinary kind.
@export var badges: Array[Texture2D] = []
## Whether their portrait wears a bow tie.
@export var wears_bow_tie := false
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
## Idle lines they show while the bus is docked, in place of the others but for sleep and
## watch lines, so the card says they are content to wait there: docked costs them nothing.
@export var docked_lines: Array[String] = [
	"Enjoying station services",
	"Calmly waiting at the station",
	"Watching the dock crew",
	"Browsing the station shops",
	"Happy to wait a moment",
	"Relaxing until departure",
]
## How many stops the bus can make on their ride before theirs, before they grow frustrated
## ([RideProgress]).
@export_range(0, 10) var stop_tolerance := 4
## Idle lines they show once a stop past their tolerance has frustrated them, and one of
## them at once at that stop.
@export var stop_lines: Array[String] = []
## Idle lines they show once the ride runs past the time they expect, and one of them at
## once when it does.
@export var late_lines: Array[String] = []
## What the card says, one of them at random, while the bus cools down after overheating.
@export var overheat_lines: Array[String] = []
## What they say, one of them at random, when the player declines their quest, when
## their quest fails, and when it is done.
@export var quest_declined_lines: Array[String] = []
@export var quest_failed_lines: Array[String] = []
@export var quest_done_lines: Array[String] = []
## The names a passenger of this type picks from.
@export var names: Array[String] = ["Passenger"]


## The idle lines a passenger of this type picks from, a copy: while [param docked], the
## docked lines, and otherwise while frustrated for [param reason], its own lines, when
## there are some.
func get_idle_lines(reason: RideProgress.Reason, docked := false) -> Array[String]:
	var lines := idle_lines
	if docked and not docked_lines.is_empty():
		lines = docked_lines
	elif reason == RideProgress.Reason.STOPS and not stop_lines.is_empty():
		lines = stop_lines
	elif reason == RideProgress.Reason.LATE and not late_lines.is_empty():
		lines = late_lines
	return lines.duplicate()


## The lines a passenger of this type says about [param event], or none for a cause that
## has no lines of its own.
func get_event_lines(event: HappinessCause.Type) -> Array[String]:
	match event:
		HappinessCause.Type.QUEST_DECLINED:
			return quest_declined_lines
		HappinessCause.Type.QUEST_FAILED:
			return quest_failed_lines
	return []
