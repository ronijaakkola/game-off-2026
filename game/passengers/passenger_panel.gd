class_name PassengerPanel
extends MarginContainer
## The passenger cards down the left edge of the screen, one for each passenger in
## [member cabin], in the order they boarded. A passenger who boards slides in from the
## left at the bottom. When the bus stops at their destination, each card going there
## shows the stars its passenger rates the ride; once the passenger gets off and the
## rating has shown for a moment, the card slides back out to the left, while the cards
## below move up to fill the gap.
## A card's serve button serves that passenger's request through the cabin.

const CARD := preload("res://game/passengers/passenger_card.tscn")

## The cabin whose passengers it shows. The cards for those already on board show at
## once, without sliding in.
@export var cabin: Cabin:
	set(value):
		if cabin:
			cabin.boarded.disconnect(_on_boarded)
			cabin.getting_off.disconnect(_on_getting_off)
			cabin.delivered.disconnect(_on_delivered)
		cabin = value
		if cabin:
			cabin.boarded.connect(_on_boarded)
			cabin.getting_off.connect(_on_getting_off)
			cabin.delivered.connect(_on_delivered)
		if is_node_ready():
			_show_all()

## Where the cards' portraits are rendered. Without one, their photos stay empty.
var portrait_studio: PortraitStudio

var _cards: Dictionary[Passenger, PassengerCard] = {}


func _ready() -> void:
	_show_all()


func _show_all() -> void:
	for card: PassengerCard in _cards.values():
		card.queue_free()
	_cards.clear()
	if cabin:
		for passenger: Passenger in cabin.get_passengers():
			_add_card(passenger)


func _on_boarded(passenger: Passenger) -> void:
	_add_card(passenger).slide_in()


func _add_card(passenger: Passenger) -> PassengerCard:
	var card := CARD.instantiate() as PassengerCard
	card.portrait_studio = portrait_studio
	card.passenger = passenger
	card.serve_pressed.connect(func() -> void: cabin.serve(passenger))
	card.left.connect(card.queue_free)
	_cards[passenger] = card
	%Cards.add_child(card)
	return card


func _on_getting_off(passenger: Passenger) -> void:
	var card: PassengerCard = _cards.get(passenger)
	if card:
		card.show_rating(passenger.get_rating())


func _on_delivered(passenger: Passenger, _payout: int) -> void:
	var card: PassengerCard = _cards.get(passenger)
	if card:
		_cards.erase(passenger)
		# Does nothing when getting_off already showed it, as at every stop. It covers a card
		# that missed getting_off, such as one made after the stop began; the rating can't
		# have changed, since patience stops when a passenger leaves their seat.
		card.show_rating(passenger.get_rating())
		card.leave()
