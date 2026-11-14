class_name PassengerPanel
extends MarginContainer
## The On board panel in the top left corner: how many seats are taken, then a card for each
## passenger in [member cabin], grouped by where they are going ([DestinationGroup]). The
## groups run in the order their planet first came up among those on board, and each
## group's cards in the order they boarded. A passenger who boards slides in from the left
## at the bottom of their group, or of a new group at the bottom. When the bus stops at
## their destination, each card going there shows the stars its passenger rates the ride;
## once the passenger gets off and the rating has shown for a moment, the card slides back
## out to the left, while the cards below move up to fill the gap, and a group whose last
## card has left folds away. A card's serve button, held down, serves that passenger's
## request through the cabin ([method Cabin.hold_serve]), and its kick button kicks them off
## the bus, so their card slides out at once. While [member arrivals_held], as in the
## tutorial while the panel itself comes in, a passenger who boards slides in only once
## it is let go. Without [member kicks_allowed], as through the tutorial, no card offers a
## kick.

const CARD := preload("res://game/passengers/passenger_card.tscn")
const GROUP := preload("res://game/passengers/destination_group.tscn")
## Pixels between the board's edge and a card's options, which sit outside it.
const OPTIONS_GAP := 6.0

## The cabin whose passengers it shows. The cards for those already on board show at
## once, without sliding in.
@export var cabin: Cabin:
	set(value):
		if cabin:
			cabin.boarded.disconnect(_on_boarded)
			cabin.getting_off.disconnect(_on_getting_off)
			cabin.delivered.disconnect(_on_delivered)
			cabin.kicked.disconnect(_on_kicked)
		cabin = value
		if cabin:
			cabin.boarded.connect(_on_boarded)
			cabin.getting_off.connect(_on_getting_off)
			cabin.delivered.connect(_on_delivered)
			cabin.kicked.connect(_on_kicked)
		if is_node_ready():
			_show_all()

## Where the cards' portraits are rendered. Without one, their photos stay empty.
var portrait_studio: PortraitStudio

## Whether those who board wait to slide in. Letting go slides them in.
var arrivals_held := false:
	set(value):
		arrivals_held = value
		if value:
			return
		var held := _held.duplicate()
		_held.clear()
		for passenger: Passenger in held:
			_on_boarded(passenger)

## Whether the cards offer to kick their passenger off.
var kicks_allowed := true:
	set(value):
		kicks_allowed = value
		for card: PassengerCard in _cards.values():
			card.kickable = value

var _cards: Dictionary[Passenger, PassengerCard] = {}
var _groups: Dictionary[Planet, DestinationGroup] = {}
var _seats_shown := Vector2i(-1, -1)
# Who boarded while arrivals were held, in order.
var _held: Array[Passenger] = []


func _ready() -> void:
	_show_all()


func _process(_delta: float) -> void:
	# An empty list would still leave its gap under the header.
	(%Cards as Control).visible = (%Cards as Control).get_child_count() > 0
	if not cabin:
		return
	var shown := Vector2i(cabin.get_passengers().size(), cabin.seats)
	if shown != _seats_shown:
		_seats_shown = shown
		(%SeatLabel as Label).text = "%d/%d" % [shown.x, shown.y]


func _show_all() -> void:
	for group: Node in %Cards.get_children():
		group.queue_free()
	_cards.clear()
	_groups.clear()
	if cabin:
		for passenger: Passenger in cabin.get_passengers():
			_add_card(passenger)
	_show_counts()


## [param passenger]'s card, or null.
func get_card(passenger: Passenger) -> PassengerCard:
	return _cards.get(passenger)


func _on_boarded(passenger: Passenger) -> void:
	if arrivals_held:
		_held.append(passenger)
		return
	var new_group := not _groups.has(passenger.destination)
	_add_card(passenger).slide_in()
	if new_group:
		_groups[passenger.destination].fade_in()
	_show_counts()


func _add_card(passenger: Passenger) -> PassengerCard:
	var card := CARD.instantiate() as PassengerCard
	card.portrait_studio = portrait_studio
	var board := $Board as Control
	card.options_gap = board.get_theme_stylebox(&"panel").content_margin_right + OPTIONS_GAP
	card.passenger = passenger
	card.kickable = kicks_allowed
	card.serve_held.connect(func(held: bool) -> void: cabin.hold_serve(passenger, held))
	card.kick_pressed.connect(func() -> void: cabin.kick(passenger))
	_cards[passenger] = card
	_group_for(passenger.destination).add_card(card)
	return card


# The group for those going to [param planet], made at the bottom if there is none yet.
func _group_for(planet: Planet) -> DestinationGroup:
	var group: DestinationGroup = _groups.get(planet)
	if group:
		return group
	group = GROUP.instantiate() as DestinationGroup
	group.planet = planet
	group.emptied.connect(_on_group_emptied.bind(group))
	group.folded.connect(group.queue_free)
	_groups[planet] = group
	%Cards.add_child(group)
	return group


func _on_group_emptied(group: DestinationGroup) -> void:
	if _groups.get(group.planet) == group:
		_groups.erase(group.planet)
	group.fold_away()


func _show_counts() -> void:
	for planet: Planet in _groups:
		var count := 0
		for passenger: Passenger in _cards:
			if passenger.destination == planet:
				count += 1
		_groups[planet].show_count(count)


func _on_getting_off(passenger: Passenger) -> void:
	var card: PassengerCard = _cards.get(passenger)
	if card:
		card.show_rating(passenger.get_rating())


func _on_delivered(passenger: Passenger, _payout: int) -> void:
	_held.erase(passenger)
	var card: PassengerCard = _cards.get(passenger)
	if card:
		_cards.erase(passenger)
		# Does nothing when getting_off already showed it, as at every stop. It covers a card
		# that missed getting_off, such as one made after the stop began; the rating can't
		# have changed, since happiness stops when a passenger leaves their seat.
		card.show_rating(passenger.get_rating())
		card.leave()
		_show_counts()


func _on_kicked(passenger: Passenger) -> void:
	_held.erase(passenger)
	var card: PassengerCard = _cards.get(passenger)
	if card:
		_cards.erase(passenger)
		card.leave()
		_show_counts()
