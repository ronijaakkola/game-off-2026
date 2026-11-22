class_name HappinessCause
extends RefCounted
## What is moving a passenger's happiness, for the panel the pointer on their happiness
## bar opens ([HappinessBreakdown]): what lifts it ([method get_ups]) and what costs them
## ([method get_downs]). Most of it is read off the passenger as they are; a one-off that
## leaves no trace on them, such as a quest declined, is an event ([method mark]), which
## [Passenger] runs and which stays listed for [constant EVENT_SECONDS]. For its first
## [constant GLARE_SECONDS] their face shows it too ([method get_glare]).

enum Type { NONE, QUEST_DECLINED, QUEST_FAILED }

## Seconds an event stays listed: about as long as its shock takes to wear off.
const EVENT_SECONDS := 15.0
const EVENT_LABELS: Dictionary[Type, String] = {
	Type.QUEST_DECLINED: "Quest declined",
	Type.QUEST_FAILED: "Quest failed",
}

## Seconds the face glares at an event, and how angry it looks for each, from 0 to 1:
## annoyed at a quest declined, furious at one failed, as it costs three times as much.
const GLARE_SECONDS := 1.5
const GLARE: Dictionary[Type, float] = {
	Type.QUEST_DECLINED: 0.5,
	Type.QUEST_FAILED: 1.0,
}

## The event under way, or none.
var event := Type.NONE

var _event_left := 0.0


## An event just cost them: [param type] is listed from now. None changes nothing.
func mark(type: Type) -> void:
	if type == Type.NONE:
		return
	event = type
	_event_left = EVENT_SECONDS


## How angry their face looks at the event under way, from 0 to 1: its glare for the
## first [constant GLARE_SECONDS], then 0.
func get_glare() -> float:
	if event == Type.NONE or _event_left < EVENT_SECONDS - GLARE_SECONDS:
		return 0.0
	return GLARE.get(event, 0.0)


## Runs [param delta] seconds of the event under way.
func run(delta: float) -> void:
	_event_left = maxf(_event_left - delta, 0.0)
	if _event_left <= 0.0:
		event = Type.NONE


## What lifts [param passenger]'s happiness on a bus giving [param comfort], a few words
## each: what they were just served, or that they are getting over something while it
## climbs for no other reason, then the comfort's perks, the station lounge they waited
## in, a quick stop, a quest done.
static func get_ups(passenger: Passenger, comfort: Comfort) -> Array[String]:
	var ups: Array[String] = []
	if passenger.served:
		ups.append("Got %s" % passenger.served.item)
	elif passenger.trend > 0.0:
		ups.append("Feeling better")
	ups.append_array(comfort.perks)
	if passenger.lounge_bonus > 0.0:
		ups.append("Station lounge")
	if passenger.quick_bonus > 0.0:
		ups.append("Quick stop")
	if passenger.quest_bonus > 0.0:
		ups.append("Quest done")
	return ups


## What costs [param passenger] happiness on a bus giving [param comfort], a few words
## each, the largest first: a request nobody serves, the event under way, stops past
## their tolerance, a late ride, the heat. A request costs nothing while it is being served,
## as the station does while the bus is [param docked].
static func get_downs(passenger: Passenger, comfort: Comfort, docked: bool) -> Array[String]:
	var downs: Array[String] = []
	# An open request costs them once it sends them toward 0, unless something serves it.
	var served := docked or passenger.being_fed
	if passenger.request and not served and passenger.get_target(comfort) <= 0.0:
		downs.append("Waiting for %s" % passenger.request.item)
	if passenger.cause.event != Type.NONE:
		downs.append(EVENT_LABELS[passenger.cause.event])
	var stops := passenger.ride.get_extra_stops()
	if stops == 1:
		downs.append("Extra stop")
	elif stops > 1:
		downs.append("%d extra stops" % stops)
	if passenger.ride.get_late_seconds() > 0.0:
		downs.append("Running late")
	if comfort.discomfort > 0.0:
		downs.append("Too hot")
	return downs
