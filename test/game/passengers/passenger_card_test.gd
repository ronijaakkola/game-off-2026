extends GdUnitTestSuite
## A passenger card's happiness bar shows their mood's colour, and blends into the new
## mood's when it changes. Getting off, the bar's row gives way to the stars they rate the
## ride, which fill up. The
## card's linger-then-slide-out is tested in passenger_panel_test.gd.

const SCENE := preload("res://game/passengers/passenger_card.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")

var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion


func after_test() -> void:
	# Assigning re-saves the developer's own settings file, so only when it changed.
	if Settings.reduce_motion != _reduce_motion:
		Settings.reduce_motion = _reduce_motion


func test_a_new_passengers_bar_shows_their_mood_at_once() -> void:
	var card := _card(1.0)
	assert_that(_fill(card).bg_color).is_equal(PassengerCard.MOOD_COLORS[Passenger.Mood.HAPPY])


func test_a_mood_change_blends_the_bar_into_the_new_mood() -> void:
	var card := _card(1.0)
	card.passenger.happiness = Passenger.MAX_HAPPINESS * 0.5
	await await_idle_frame()
	await await_idle_frame()

	# Still on its way while it blends.
	var okay := PassengerCard.MOOD_COLORS[Passenger.Mood.OKAY]
	assert_that(_fill(card).bg_color).is_not_equal(okay)

	await get_tree().create_timer(PassengerCard.MOOD_FADE_SECONDS + 0.1).timeout

	assert_that(_fill(card).bg_color).is_equal(okay)


func test_showing_the_rating_swaps_the_trip_row_for_stars_that_fill_up() -> void:
	_set_reduce_motion(false)
	var card := _card(0.1)
	await await_idle_frame()

	card.show_rating(2.0)
	var stars := card.find_child("RatingStars", true, false) as StarIcon
	var trip := card.find_child("Trip", true, false) as Control
	await get_tree().create_timer(PassengerCard.SWAP_SECONDS * 0.5).timeout
	# The row sinks as it fades, and the stars come from above, still empty.
	assert_float(trip.position.y).is_greater(0.0)
	assert_float(trip.modulate.a).is_less(1.0)
	assert_bool(stars.visible).is_true()
	assert_float(stars.fill).is_equal(0.0)
	assert_float(stars.position.y).is_less((trip.size.y - stars.size.y) * 0.5)

	await get_tree().create_timer(PassengerCard.SWAP_SECONDS + 0.1).timeout
	# Filling, one star after another.
	assert_float(stars.fill).is_greater(0.0)
	assert_float(stars.fill).is_less(2.0)
	await get_tree().create_timer(2.0 * PassengerCard.STAR_FILL_SECONDS + 0.1).timeout

	assert_float(stars.fill).is_equal(2.0)
	assert_int(stars.count).is_equal(5)
	assert_bool(stars.bump).is_true()
	assert_float(stars.modulate.a).is_equal(1.0)
	assert_float(trip.modulate.a).is_equal(0.0)
	var activity := card.find_child("ActivityLabel", true, false) as Label
	assert_str(activity.text).is_equal("Getting off")
	# The top row stays as it was.
	var name_label := card.find_child("NameLabel", true, false) as Label
	assert_str(name_label.text).is_equal(card.passenger.name)
	assert_bool(card.is_rated()).is_true()


func test_reduce_motion_only_crossfades_the_rating_in() -> void:
	_set_reduce_motion(true)
	var card := _card(1.0)
	await await_idle_frame()

	card.show_rating(5.0)
	var stars := card.find_child("RatingStars", true, false) as StarIcon
	var trip := card.find_child("Trip", true, false) as Control
	await get_tree().create_timer(PassengerCard.SWAP_SECONDS * 0.5).timeout

	assert_float(trip.position.y).is_equal(0.0)
	assert_float(stars.position.y).is_equal_approx((trip.size.y - stars.size.y) * 0.5, 0.01)
	assert_bool(stars.bump).is_false()


func test_once_rated_the_card_stops_following_the_passenger() -> void:
	var card := _card(1.0)
	await await_idle_frame()
	card.show_rating(5.0)
	card.passenger.happiness = 0.0
	card.passenger.activity = "Something else"
	await get_tree().create_timer(PassengerCard.MOOD_FADE_SECONDS + 0.1).timeout

	assert_that(_fill(card).bg_color).is_equal(PassengerCard.MOOD_COLORS[Passenger.Mood.HAPPY])
	var activity := card.find_child("ActivityLabel", true, false) as Label
	assert_str(activity.text).is_equal("Getting off")


func test_a_big_drop_leaves_a_trail_that_holds_then_shrinks_to_the_bar() -> void:
	var card := _card(0.8)
	await await_idle_frame()
	card.passenger.shock(-30.0)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(_bar(card).value).is_equal_approx(0.5, 0.001)
	assert_float(_trail(card).value).is_equal_approx(0.8, 0.001)

	await get_tree().create_timer(PassengerCard.TRAIL_HOLD_SECONDS * 0.5).timeout
	assert_float(_trail(card).value).is_equal_approx(0.8, 0.001)

	var shrink := 0.3 / PassengerCard.TRAIL_SHRINK_RATE
	await get_tree().create_timer(PassengerCard.TRAIL_HOLD_SECONDS + shrink + 0.2).timeout
	assert_float(_trail(card).value).is_equal_approx(0.5, 0.001)


func test_a_small_drop_leaves_no_trail_and_a_rise_takes_it_along() -> void:
	var card := _card(0.8)
	await await_idle_frame()
	card.passenger.happiness -= 2.0
	await get_tree().create_timer(0.15).timeout
	assert_float(_trail(card).value).is_equal_approx(_bar(card).value, 0.001)
	card.passenger.happiness = 95.0
	await await_idle_frame()
	await await_idle_frame()
	assert_float(_trail(card).value).is_equal_approx(0.95, 0.001)


func test_the_bar_moves_smoothly_rather_than_in_steps() -> void:
	var card := _card(0.5)
	card.passenger.happiness = 50.4
	await await_idle_frame()
	assert_float(_bar(card).value).is_equal_approx(0.504, 0.0001)


func _card(happiness_fraction: float) -> PassengerCard:
	var planet: Planet = auto_free(Planet.new())
	var passenger := Passenger.new(COMMUTER, planet, 60.0, 40.0)
	passenger.happiness = Passenger.MAX_HAPPINESS * happiness_fraction
	var card: PassengerCard = auto_free(SCENE.instantiate())
	card.passenger = passenger
	add_child(card)
	return card


func _fill(card: PassengerCard) -> StyleBoxFlat:
	var bar := _bar(card)
	return bar.get_theme_stylebox(&"fill") as StyleBoxFlat


func _set_reduce_motion(on: bool) -> void:
	if Settings.reduce_motion != on:
		Settings.reduce_motion = on


func _bar(card: PassengerCard) -> ProgressBar:
	return card.find_child("HappinessBar") as ProgressBar


func _trail(card: PassengerCard) -> ProgressBar:
	return card.find_child("HappinessTrail") as ProgressBar
