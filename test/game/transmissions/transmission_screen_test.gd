extends GdUnitTestSuite
## The caller on the transmission screen is dressed as their passenger's photo is: a
## Business caller in their type's bow tie, the boss and a Commuter without one.

const SCENE := "res://game/transmissions/transmission_screen.tscn"
const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const BUSINESS := preload("res://game/passengers/types/business.tres")


func test_a_business_caller_wears_a_bow_tie_and_the_others_don_t() -> void:
	var runner := scene_runner(SCENE)
	var screen := runner.scene() as TransmissionScreen
	var worn: Array[bool] = []
	for call: Transmission in [_call(BUSINESS), _call(COMMUTER), Transmission.from_boss()]:
		screen.show_caller(call)
		await runner.simulate_frames(1)
		worn.append(_wears_bow_tie(screen))
	assert_array(worn).is_equal([true, false, false])


func _call(type: PassengerType) -> Transmission:
	var planet: Planet = auto_free(Planet.new())
	return Transmission.from_passenger(Passenger.new(type, planet, 60.0, 40.0))


# The screen shows one caller at a time; the last is freed by the frame after the next.
static func _wears_bow_tie(screen: TransmissionScreen) -> bool:
	var ties := screen.find_children("*Tie", "MeshInstance3D", true, false)
	return ties.size() == 1 and (ties[0] as MeshInstance3D).visible
