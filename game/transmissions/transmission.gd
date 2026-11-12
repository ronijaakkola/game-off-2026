class_name Transmission
extends RefCounted
## A call that pauses the game: someone on a screen says [member text], and the player
## answers with a button. A message only says something; a quest also asks the player to
## take on [member quest], for a reward, and to accept or decline it. What an answer does
## is up to whoever opens the [TransmissionPanel].

## Who calls, and how their portrait looks.
var caller_name := ""
var look: AlienLook
## The caller's race: the screen's backdrop and frame are in its colours.
var race := Race.Type.GREEN
## The caller's passenger type, whose badges sit on the screen's corner with their tooltip,
## as on a passenger's portrait, or null for a caller who isn't a passenger.
var type: PassengerType
## Where the caller is going, shown after their name, or null.
var destination: Planet
## The face the caller makes on the screen: anger frowns, a happy caller beams now and then.
var mood := Passenger.Mood.OKAY
## What they say.
var text := ""
## What a quest asks, as a short line, or empty for a message. [member quest_planet], when
## set, follows it with its icon and name.
var quest := ""
var quest_planet: Planet
## What a quest pays when it is done. Nothing shows when both are empty.
var reward_credits := 0
var reward_research: Dictionary[Race.Type, int] = {}
## The primary button's label, and the quiet button's beside it. Without a decline label
## there is only the primary button.
var accept_text := "Got it"
var decline_text := ""


## A transmission from [param passenger], in their look, mood and badges.
static func from_passenger(passenger: Passenger) -> Transmission:
	var transmission := Transmission.new()
	transmission.caller_name = passenger.name
	transmission.look = passenger.look
	transmission.race = passenger.race
	transmission.type = passenger.type
	transmission.destination = passenger.destination
	transmission.mood = passenger.get_mood()
	return transmission


## Whether it asks the player to take on a quest.
func is_quest() -> bool:
	return quest != ""


## Whether it shows a reward.
func has_reward() -> bool:
	return reward_credits > 0 or not reward_research.is_empty()
