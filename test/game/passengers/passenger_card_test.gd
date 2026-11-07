extends GdUnitTestSuite
## A passenger card's mood name shakes for the low moods, and holds still under Reduce
## motion. When the mood changes, the name fades out and back in as the new one.

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


func test_a_new_passengers_mood_shows_at_once() -> void:
	var card := _card(1.0)
	assert_str(_mood_label(card).text).is_equal("Happy")
	assert_float(_mood_label(card).modulate.a).is_equal(1.0)
	assert_that(_fill(card).bg_color).is_equal(PassengerCard.MOOD_COLORS[Passenger.Mood.HAPPY])


func test_a_mood_change_fades_the_name_out_and_back_in_as_the_new_mood() -> void:
	_set_reduce_motion(true)
	var card := _card(1.0)
	card.passenger.patience = card.passenger.patience_max * 0.5
	await await_idle_frame()
	await await_idle_frame()

	# Still the old name while it fades out.
	assert_str(_mood_label(card).text).is_equal("Happy")
	assert_float(_mood_label(card).modulate.a).is_less(1.0)

	await get_tree().create_timer(PassengerCard.MOOD_FADE_SECONDS + 0.1).timeout

	assert_str(_mood_label(card).text).is_equal("Okay")
	assert_float(_mood_label(card).modulate.a).is_equal(1.0)
	assert_that(_fill(card).bg_color).is_equal(PassengerCard.MOOD_COLORS[Passenger.Mood.OKAY])


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


func _fill(card: PassengerCard) -> StyleBoxFlat:
	var bar := card.find_child("PatienceBar") as ProgressBar
	return bar.get_theme_stylebox(&"fill") as StyleBoxFlat


func _set_reduce_motion(on: bool) -> void:
	if Settings.reduce_motion != on:
		Settings.reduce_motion = on
