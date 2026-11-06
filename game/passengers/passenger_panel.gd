extends MarginContainer
## The passenger cards down the left edge of the screen, one for each passenger in
## [member cabin], in the order they boarded. A card's serve button serves that
## passenger's request through the cabin.

const CARD := preload("res://game/passengers/passenger_card.tscn")

## The cabin whose passengers it shows.
@export var cabin: Cabin:
	set(value):
		if cabin:
			cabin.boarded.disconnect(_add_card)
			cabin.delivered.disconnect(_on_delivered)
		cabin = value
		if cabin:
			cabin.boarded.connect(_add_card)
			cabin.delivered.connect(_on_delivered)
		if is_node_ready():
			_show_all()

var _cards: Dictionary[Passenger, Control] = {}


func _ready() -> void:
	_show_all()


func _show_all() -> void:
	for card: Control in _cards.values():
		card.queue_free()
	_cards.clear()
	if cabin:
		for passenger: Passenger in cabin.get_passengers():
			_add_card(passenger)


func _add_card(passenger: Passenger) -> void:
	var card := CARD.instantiate()
	card.set(&"passenger", passenger)
	card.connect(&"serve_pressed", func() -> void: cabin.serve(passenger))
	_cards[passenger] = card
	%Cards.add_child(card)


func _on_delivered(passenger: Passenger, _payout: int) -> void:
	var card: Control = _cards.get(passenger)
	if card:
		_cards.erase(passenger)
		card.queue_free()
