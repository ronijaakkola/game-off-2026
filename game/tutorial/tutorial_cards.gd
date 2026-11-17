class_name TutorialCards
extends RefCounted
## The tutorial's guide cards on its one [GuideCard], one at a time: [method open] puts a
## step's card on its target, once the card before has gone and a beat, so it never moves
## from one target to the next. [constant CARDS] has each card, by the name of the step it
## is on ([enum Tutorial.Step]): its title, what it says, the side of its target it sits
## on, and whether it has a Got it button, which only a card that just tells the player
## something has. The [ResearchGuide] opens its own cards through it the same way. {home} and
## {destination} stand for the planets' names, {stars} for the rating the passenger gave.
## The titles are placeholders.

## Seconds from a card starting to close to the next one opening: once it has gone, and a
## beat.
const GAP := Tooltip.CLOSE_SECONDS + 0.25
const CARDS := {
	"BUS":
	{
		title = "Your bus",
		text = "You are driving this bus. It is currently docked at planet called {home}.",
		side = GuideCard.Side.RIGHT,
		got_it = true,
	},
	"BOARD":
	{
		title = "Your first passenger",
		text =
		(
			"Here you can see a list of waiting passengers. This one is headed to planet "
			+ '{destination}. Press "Board" to let them in.'
		),
		side = GuideCard.Side.LEFT,
		got_it = false,
	},
	"ON_BOARD":
	{
		title = "On board",
		text =
		(
			"Here you can see passengers currently inside your bus. There is one now looking for "
			+ "their seat!"
		),
		side = GuideCard.Side.RIGHT,
		got_it = true,
	},
	"HAPPINESS":
	{
		title = "Happiness",
		text =
		(
			"This bar shows how happy they are. Keep them as happy as possible, and they will "
			+ "pay more and rate your company better."
		),
		side = GuideCard.Side.RIGHT,
		got_it = true,
	},
	"ROUTE":
	{
		title = "Set a course",
		text =
		(
			"The passenger you just picked up wants to go to {destination}. Right click the "
			+ "planet to set it as your destination."
		),
		side = GuideCard.Side.LEFT,
		got_it = false,
	},
	"CHARGE":
	{
		title = "Leave",
		text =
		(
			"Now that your route is set, press and hold this button to charge your buses "
			+ "frameshift drive to start the trip to {destination}!"
		),
		side = GuideCard.Side.ABOVE,
		got_it = false,
	},
	"SERVE":
	{
		title = "A request",
		text =
		(
			"To keep your passengers happy, you need to serve them during their trip. This "
			+ "one is hungry. Press and hold this button to hand them a snack!"
		),
		side = GuideCard.Side.RIGHT,
		got_it = false,
	},
	"RATING":
	{
		title = "Rating",
		text =
		(
			"This passenger enjoyed their quick ride and gave you {stars}. Good ratings will "
			+ "attract more and better passengers."
		),
		side = GuideCard.Side.RIGHT,
		got_it = true,
	},
	"MONEY":
	{
		title = "Rewards",
		text =
		(
			"The passenger paid for the trip with some credits. They also awarded you with a research "
			+ "point. Every passenger you deliver gives you one."
		),
		side = GuideCard.Side.BELOW,
		got_it = true,
	},
	"REFUEL":
	{
		title = "Fuel",
		text =
		(
			"Frameshifting consumes a lot of fuel. Refuel at any planet by pressing and holding this "
			+ "button. Getting towed in space is not cheap, so remember to refuel!"
		),
		side = GuideCard.Side.LEFT,
		got_it = false,
	},
}

var _guide: GuideCard
var _cards: Dictionary
# The step whose card is open or on its way, or empty for none.
var _open_for := ""


## Opens cards on [param guide]: the tutorial's, or [param cards] in the same shape.
func _init(guide: GuideCard, cards: Dictionary = CARDS) -> void:
	_guide = guide
	_cards = cards


## Opens [param step]'s card on [param target], or on [member GuideCard.target_rect] when
## it is null, with [param names] filling in its text. While a card still shows, it waits
## until that one has gone, and a beat; another card opened meanwhile wins. It returns once
## the card opens, or would have.
func open(step: String, target: Control, names: Dictionary) -> void:
	_open_for = step
	if _guide.visible:
		await _guide.get_tree().create_timer(GAP).timeout
		if _open_for != step:
			return
	var card: Dictionary = _cards[step]
	_guide.target = target
	_guide.title = card.title
	_guide.text = (card.text as String).format(names)
	_guide.side = card.side
	_guide.got_it = card.got_it
	_guide.open()


## Closes the card showing, where it is.
func close() -> void:
	_open_for = ""
	_guide.close()


## Whether [param step]'s card is open, or on its way.
func is_open_for(step: String) -> bool:
	return _open_for == step
