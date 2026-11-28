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
## Who the mechanic is: a brown alien with the Bean's shape, holding a wrench, over a steel
## blue-green backdrop. No race is brown; they talk in the blue one's voice.
const MECHANIC_NAME := "Rusty, the Mechanic"
const MECHANIC_HEAD := preload("res://game/transmissions/models/head_mechanic.glb")
const MECHANIC_SKIN := Color(0.52, 0.33, 0.2)
const MECHANIC_BACKDROP := Color(0.3, 0.5, 0.56)
const MECHANIC_RACE := Race.Type.BLUE

## Who calls, and how their portrait looks.
var caller_name := ""
## What a call notice names them while the player doesn't know them yet, or empty for the
## notice's own "Unknown caller".
var unknown_name := ""
var look: AlienLook
## The caller's race: they talk in its voice, and the screen's backdrop is its deep shade.
var race := Race.Type.GREEN
## The screen's backdrop for a caller who isn't in front of their race's, or see-through
## for the race's deep shade.
var backdrop_color := Color.TRANSPARENT
## Whether the caller floats in space: the backdrop is stars and fog in
## [member backdrop_color], with no sky or ground.
var in_space := false
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
## What they say, in BBCode: [code][money]...[/code] shows the words in gold, shimmering
## ([MoneyEffect]), and [code][shout]...[/code] shakes them ([ShoutEffect]).
var text := ""
## What a quest asks, as a short line, or empty for a message. [member quest_planet], when
## set, follows it with its icon and name.
var quest := ""
var quest_planet: Planet
## What follows the planet's name there, such as "when hot enough", or empty.
var quest_condition := ""
## The planets a quest asks for after that one, in order, shown under it, as a VIP's tour.
var quest_stops: Array[Planet] = []
## What a quest pays when it is done. Nothing shows when both are empty.
var reward_credits := 0
var reward_research := 0
## The primary button's label, and the quiet button's beside it. Without a decline label
## there is only the primary button.
var accept_text := "Got it"
var decline_text := ""
## Whether the two buttons are two ways to say the same thing, for flavour: both look like
## the primary button, as wide as each other, the decline label on the left, and either
## accepts.
var answers_alike := false


## A transmission from [param passenger], in their look, mood and badges. The [Castaway]
## calls from space.
static func from_passenger(passenger: Passenger) -> Transmission:
	var transmission := Transmission.new()
	transmission.caller_name = passenger.name
	transmission.look = passenger.look
	transmission.race = passenger.race
	transmission.type = passenger.type
	transmission.destination = passenger.destination
	transmission.mood = passenger.get_mood()
	if Vip.is_vip(passenger):
		transmission.backdrop_color = Vip.BACKDROP
	if Castaway.is_castaway(passenger):
		transmission.backdrop_color = Castaway.get_space_color(passenger)
		transmission.in_space = true
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


## A transmission from the company's mechanic: a brown alien with a bean of a head and bead
## eyes, holding a wrench, in a good mood.
static func from_mechanic() -> Transmission:
	var transmission := Transmission.new()
	transmission.caller_name = MECHANIC_NAME
	transmission.look = AlienLook.new()
	transmission.look.head = MECHANIC_HEAD
	transmission.look.eye_style = AlienLook.EYE_STYLES[1]
	transmission.look.skin_color = MECHANIC_SKIN
	transmission.race = MECHANIC_RACE
	transmission.backdrop_color = MECHANIC_BACKDROP
	transmission.mood = Passenger.Mood.HAPPY
	return transmission


## The screen's backdrop: [member backdrop_color], or the race's deep shade without one.
func get_backdrop_color() -> Color:
	return Race.BACKDROP_COLORS[race] if backdrop_color.a == 0.0 else backdrop_color


## Whether it asks the player to take on a quest.
func is_quest() -> bool:
	return quest != ""


## Whether it shows a reward.
func has_reward() -> bool:
	return reward_credits > 0 or reward_research > 0
