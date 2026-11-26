class_name TutorialCards
extends RefCounted
## The tutorial's guide cards on its one [GuideCard], one at a time: [method open] puts a
## step's card on its target, once the card before has gone and a beat, so it never moves
## from one target to the next. [constant CARDS] has each card, by the name of the step it
## is on ([enum Tutorial.Step]): its title, what it says, the side of its target it sits
## on, whether it has a Got it button, which only a card that just tells the player
## something has, and whether its target is rung ([member GuideCard.ring]); one with a kind
## is that kind of card, not a tutorial step. The [ResearchGuide] opens its own cards
## through it the same way. {home} and {destination} stand for the planets' names, {stars}
## for the rating the passenger gave, {queue_key} for the key that adds a stop
## ([method QueueKey.get_icons]), and a control's name in braces for its icon
## ([ControlIcons]).
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
		ring = true,
	},
	"LOOK":
	{
		title = "Look around",
		text =
		(
			"Hold {mouse_left} and drag, or use {wasd}, to move around.\nUse the mouse wheel "
			+ "{mouse_wheel} to zoom. Try both."
		),
		side = GuideCard.Side.RIGHT,
		got_it = false,
		ring = false,
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
		ring = true,
	},
	"ON_BOARD":
	{
		title = "On board",
		text =
		(
			"Your passenger is on board. The bar shows how happy they are: keep them happy, and "
			+ "they pay more and rate your company better."
		),
		side = GuideCard.Side.RIGHT,
		got_it = true,
		ring = true,
	},
	"ROUTE":
	{
		title = "Set a course",
		text =
		"Your passenger wants to go to {destination}. Right click {mouse_right} it to set a course.",
		side = GuideCard.Side.LEFT,
		got_it = false,
		ring = true,
	},
	"CHARGE":
	{
		title = "Leave",
		text =
		(
			"Your route is set. Press and hold this button or {space} to charge the frameshift "
			+ "drive and leave for {destination}."
		),
		side = GuideCard.Side.ABOVE,
		got_it = false,
		ring = true,
	},
	"SERVE":
	{
		title = "Heard that sound?",
		text =
		(
			"To keep your passengers happy, you need to serve them during their trip. This "
			+ "one is hungry. Press and hold this button to hand them a snack!"
		),
		side = GuideCard.Side.RIGHT,
		got_it = false,
		ring = true,
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
		ring = true,
	},
	"MONEY":
	{
		title = "Rewards",
		text =
		(
			"The passenger paid for the trip with some credits. The happier they are when they "
			+ "get off, the more they pay."
		),
		side = GuideCard.Side.BELOW,
		got_it = true,
		ring = true,
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
		ring = true,
	},
	"SPOT":
	{
		title = "Capsules",
		text =
		(
			"Capsules sometimes drift in space, and they can hold all kinds of valuables. "
			+ "Right click {mouse_right} this one to fly to it and pick it up."
		),
		side = GuideCard.Side.ABOVE,
		got_it = false,
		ring = true,
	},
	"HOME":
	{
		title = "Home",
		text =
		(
			"The capsule contained some credits, nice! Now right click {mouse_right} {home} to "
			+ "fly home."
		),
		side = GuideCard.Side.LEFT,
		got_it = false,
		ring = true,
	},
	"CHAIN":
	{
		title = "Chain stops",
		text =
		(
			"Welcome home! Tip: you can also chain stops together: hold {queue_key} as you "
			+ "right click {mouse_right} to add each one to the end of your route."
		),
		side = GuideCard.Side.ABOVE,
		got_it = true,
		ring = true,
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
	_guide.kind = card.get("kind", GuideCard.Kind.TUTORIAL_STEP)
	if card.has("ring"):
		_guide.ring = card.ring
	_guide.open()


## Closes the card showing, where it is.
func close() -> void:
	_open_for = ""
	_guide.close()


## Whether [param step]'s card is open, or on its way.
func is_open_for(step: String) -> bool:
	return _open_for == step
