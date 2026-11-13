class_name Transmission
extends RefCounted
## A call that pauses the game: someone on a screen says [member text], and the player
## answers with a button. A message only says something; a quest also asks the player to
## take on [member quest], for a reward, and to accept or decline it. What an answer does
## is up to whoever opens the [TransmissionPanel].

## The boss's head: a tall, leaning tower of a blob with three eyes.
const BOSS_HEAD := preload("res://game/transmissions/models/head_boss.glb")
const BOSS_EYES := preload("res://game/passengers/eye_styles/googly.tres")
const BOSS_RACE := Race.Type.ORANGE

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
## Whether the caller sits in the dark: only their outline shows, with no eyes, colour or
## mood.
var shadowed := false
## The face the caller makes on the screen: anger frowns, a happy caller beams now and then.
var mood := Passenger.Mood.OKAY
## Whether the caller glares whatever their mood: the eyes of full anger, with no anger
## mark and no tremble.
var stern := false
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


## A transmission from the player's boss, who sits in the dark until [param revealed].
static func from_boss(revealed := false) -> Transmission:
	var transmission := Transmission.new()
	transmission.caller_name = "Your boss"
	transmission.look = AlienLook.new()
	transmission.look.head = BOSS_HEAD
	transmission.look.eye_style = BOSS_EYES
	transmission.look.skin_color = Race.SKIN_COLORS[BOSS_RACE]
	transmission.race = BOSS_RACE
	transmission.shadowed = not revealed
	transmission.stern = true
	return transmission


## Whether it asks the player to take on a quest.
func is_quest() -> bool:
	return quest != ""


## Whether it shows a reward.
func has_reward() -> bool:
	return reward_credits > 0 or not reward_research.is_empty()
