extends GdUnitTestSuite
## Which idle lines a passenger type gives, in flight and docked.


func test_docked_its_docked_lines_stand_in_for_the_others_even_when_frustrated() -> void:
	var kind := _type()
	assert_array(kind.get_idle_lines(RideProgress.Reason.STOPS, true)).is_equal(["Calmly waiting"])
	assert_array(kind.get_idle_lines(RideProgress.Reason.STOPS)).is_equal(["Another stop?"])
	assert_array(kind.get_idle_lines(RideProgress.Reason.NONE)).is_equal(["Reading"])


func test_docked_without_docked_lines_it_gives_its_usual_ones() -> void:
	var kind := _type()
	kind.docked_lines = []
	assert_array(kind.get_idle_lines(RideProgress.Reason.NONE, true)).is_equal(["Reading"])


func test_every_kind_has_docked_lines() -> void:
	for path: String in ["business", "commuter"]:
		var kind: PassengerType = load("res://game/passengers/types/%s.tres" % path)
		assert_array(kind.docked_lines).is_not_empty()


func _type() -> PassengerType:
	var kind := PassengerType.new()
	kind.idle_lines = ["Reading"]
	kind.stop_lines = ["Another stop?"]
	kind.docked_lines = ["Calmly waiting"]
	return kind
