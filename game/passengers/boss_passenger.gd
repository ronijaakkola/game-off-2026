class_name BossPassenger
## The Boss as a passenger, who waits at a planet to be picked up ([BossPickUp]): the one
## who calls with every promotion, with the same head, eyes and colour. Until the player
## meets them they are nobody the player knows, named [constant UNKNOWN_NAME] under their
## outline in the dark with a question mark over it ([PhotoMark]), and the outline is
## someone else's, with two eyes on stalks ([constant DISGUISE]), so the player doesn't
## guess who waits; [method reveal] names them and gives them their own look. They take
## every seat the bus has ([Seating]) and never sleep. They are going nowhere, pay nothing
## and expect no time, so they are as happy as can be all ride and ask for nothing
## ([Passenger]), and nobody kicks them off. A save keeps
## a look as one of its race's heads, so The Boss from a save is dressed again
## ([method dress]). Once their errand is run ([BossErrand]) they are dressed for the
## board, in a bow tie and with a briefcase ([method dress_up]): another type, the same but
## for those, so a save keeps it. Their head has no bow tie to show yet.

const TYPE: PassengerType = preload("res://game/passengers/types/boss.tres")
## What they are once dressed for the board.
const DRESSED_TYPE: PassengerType = preload("res://game/passengers/types/boss_dressed.tres")
const NAME := "The Boss"
## What they go by until the player meets them.
const UNKNOWN_NAME := "???"
## What their card says as they board, in place of finding a seat.
const BOARDING_LINE := "Taking all the seats..."
## The head whose outline they show until the player meets them.
const DISGUISE := preload("res://game/passengers/models/head_stalks.glb")
## A trip time no ride outlasts, in seconds, for someone who expects to get nowhere.
const FOREVER := 1.0e6


## The Boss waiting at [param at], not yet known.
static func create(at: Planet) -> Passenger:
	var boss := Passenger.new(TYPE, null, FOREVER, 0.0)
	boss.origin = at
	boss.name = UNKNOWN_NAME
	boss.activity = BOARDING_LINE
	dress(boss)
	boss.look.head = DISGUISE
	return boss


## Gives [param passenger] The Boss's race and look.
static func dress(passenger: Passenger) -> void:
	passenger.race = Transmission.BOSS_RACE
	passenger.look = Transmission.from_boss().look


## Whether [param passenger] is The Boss.
static func is_boss(passenger: Passenger) -> bool:
	return passenger != null and (passenger.type == TYPE or passenger.type == DRESSED_TYPE)


## Dresses [param passenger], The Boss, for the board: a bow tie and a briefcase.
static func dress_up(passenger: Passenger) -> void:
	passenger.type = DRESSED_TYPE


## Whether [param passenger] is The Boss before the player has met them.
static func is_unknown(passenger: Passenger) -> bool:
	return is_boss(passenger) and passenger.name == UNKNOWN_NAME


## The player has met [param passenger], The Boss: they go by their name, in their own
## look.
static func reveal(passenger: Passenger) -> void:
	passenger.name = NAME
	dress(passenger)
