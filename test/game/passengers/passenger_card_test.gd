extends GdUnitTestSuite
## A passenger card's mood name shakes for the low moods, and holds still under Reduce
## motion. When the mood changes, the name fades out and back in as the new one. Getting
## off, the mood name turns into the stars they rate the ride, and the card lingers before
## it slides out.

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


func test_showing_the_rating_swaps_the_mood_for_stars_and_says_so() -> void:
	var card := _card(1.0)
	await await_idle_frame()

	card.show_rating(4.0)
	await get_tree().create_timer(PassengerCard.MOOD_FADE_SECONDS + 0.1).timeout

	var stars := card.find_child("RatingStars", true, false) as StarIcon
	assert_bool(_mood_label(card).visible).is_false()
	assert_bool(stars.visible).is_true()
	assert_float(stars.modulate.a).is_equal(1.0)
	assert_int(stars.count).is_equal(5)
	assert_int(stars.filled).is_equal(4)
	var activity := card.find_child("ActivityLabel", true, false) as Label
	assert_str(activity.text).is_equal(PassengerCard.rating_line(4.0))
	var destination := card.find_child("DestinationLabel", true, false) as Label
	assert_str(destination.text).starts_with("Getting off at ")
	assert_bool(card.is_rated()).is_true()


func test_once_rated_the_card_stops_following_the_passenger() -> void:
	var card := _card(1.0)
	await await_idle_frame()
	card.show_rating(5.0)
	card.passenger.patience = 0.0
	card.passenger.activity = "Something else"
	await get_tree().create_timer(PassengerCard.MOOD_FADE_SECONDS + 0.1).timeout

	assert_bool(_mood_label(card).visible).is_false()
	var activity := card.find_child("ActivityLabel", true, false) as Label
	assert_str(activity.text).is_equal(PassengerCard.rating_line(5.0))


func test_a_rated_card_lingers_before_it_slides_out() -> void:
	var card := _card(1.0)
	await await_idle_frame()
	card.show_rating(2.0)
	card.leave()
	var panel := card.find_child("Panel", true, false) as Control

	await get_tree().create_timer(PassengerCard.LINGER_SECONDS - 0.3).timeout
	assert_float(panel.position.x).is_equal(0.0)
	await assert_signal(card).wait_until(2000).is_emitted("left")
	assert_float(panel.position.x).is_less(0.0)


func test_rating_lines_go_from_glowing_to_furious() -> void:
	assert_str(PassengerCard.rating_line(5.0)).is_equal("Loved the ride!")
	assert_str(PassengerCard.rating_line(4.0)).is_equal("Thanks for the ride.")
	assert_str(PassengerCard.rating_line(2.0)).is_equal("That took forever...")
	assert_str(PassengerCard.rating_line(0.0)).is_equal("Never riding this again!")


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
