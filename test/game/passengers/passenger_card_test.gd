extends GdUnitTestSuite
## A passenger card's mood name shakes for the low moods, and holds still under Reduce
## motion.

const SCENE := preload("res://game/passengers/passenger_card.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")

var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion


func after_test() -> void:
	# Assigning re-saves the developer's own settings file, so only when it changed.
	if Settings.reduce_motion != _reduce_motion:
		Settings.reduce_motion = _reduce_motion


func test_an_annoyed_passengers_mood_shakes() -> void:
	_set_reduce_motion(false)
	var card := _card(0.1)
	assert_str(_mood_label(card).text).starts_with("[shake")


func test_reduce_motion_holds_the_mood_still() -> void:
	_set_reduce_motion(true)
	var card := _card(0.1)
	assert_str(_mood_label(card).text).is_equal("Annoyed")
	assert_str(_mood_label(card).get_parsed_text()).is_equal("Annoyed")


func test_turning_on_reduce_motion_stops_a_shaking_mood() -> void:
	_set_reduce_motion(false)
	var card := _card(0.0)
	assert_str(_mood_label(card).text).contains("[shake")

	_set_reduce_motion(true)
	await await_idle_frame()

	assert_str(_mood_label(card).text).is_equal("Furious")


func _card(patience_fraction: float) -> PassengerCard:
	var planet: Planet = auto_free(Planet.new())
	var passenger := Passenger.new(COMMUTER, planet, 60.0, 40.0)
	passenger.patience = passenger.patience_max * patience_fraction
	var card: PassengerCard = auto_free(SCENE.instantiate())
	card.passenger = passenger
	add_child(card)
	return card


func _mood_label(card: PassengerCard) -> RichTextLabel:
	return card.find_child("MoodLabel") as RichTextLabel


func _set_reduce_motion(on: bool) -> void:
	if Settings.reduce_motion != on:
		Settings.reduce_motion = on
