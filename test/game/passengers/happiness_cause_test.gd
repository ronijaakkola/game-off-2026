extends GdUnitTestSuite
## What moves a passenger's happiness as their quest ends, and how they show it: what they
## say, the face they pull, the lift and dance a quest done gives, and the card's line.

const TRIP := 100.0
const FARE := 50.0
const START := Passenger.BASE_HAPPINESS

var _planet: Planet


func before_test() -> void:
	_planet = auto_free(Planet.new())


func test_a_sleeper_woken_by_a_declined_quest_says_so_and_glares_for_a_moment() -> void:
	var kind := PassengerType.new()
	kind.quest_declined_lines = ["Fine"]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.asleep = true
	passenger.shock(-5.0, HappinessCause.Type.QUEST_DECLINED)
	assert_str(passenger.activity).is_equal("Fine")
	assert_float(passenger.cause.get_glare()).is_equal(0.5)
	passenger.cause.run(HappinessCause.GLARE_SECONDS + 0.1)
	assert_float(passenger.cause.get_glare()).is_equal(0.0)


func test_a_quest_done_lifts_them_sets_them_dancing_and_says_so() -> void:
	var kind := PassengerType.new()
	kind.quest_done_lines = ["Thanks"]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.admire(20.0, true)
	assert_float(passenger.happiness).is_equal(START + 20.0)
	assert_float(passenger.get_target()).is_equal(START + 20.0)
	assert_float(passenger.dancing).is_equal(Passenger.DANCE_SECONDS)
	assert_str(passenger.activity).is_equal("Thanks")
	assert_array(HappinessCause.get_ups(passenger, Comfort.new())).contains(["Quest done"])
