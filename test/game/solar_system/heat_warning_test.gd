extends GdUnitTestSuite
## Overheating in the solar system: everyone on board takes a small shock, an error notice
## shows while the bus cools down, and an info notice says when it has.

const SCENE := "res://game/solar_system/solar_system.tscn"
const HEAT_WARNING := preload("res://game/solar_system/heat_warning.gd")


func test_overheating_shocks_everyone_and_notices_follow_the_cooldown() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var cabin := runner.find_child("Cabin") as Cabin
	var notices := runner.find_child("Notices") as NoticeStack
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var passenger := waiting.create(bus.get_docked_planet())
	cabin.board(passenger)
	var before := passenger.happiness
	var temperature := bus.temperature
	temperature.cooldown_time = 0.3

	temperature.set_temperature(temperature.overheat_temperature)
	await runner.simulate_frames(2)

	assert_float(passenger.happiness).is_equal_approx(before + HEAT_WARNING.OVERHEAT_SHOCK, 0.01)
	assert_array(_texts(notices)).contains([HEAT_WARNING.OVERHEATED_TEXT])
	await await_millis(500)
	await runner.simulate_frames(2)
	assert_bool(temperature.is_cooling()).is_false()
	assert_array(_texts(notices)).contains([HEAT_WARNING.COOLED_TEXT])


# The texts of the notices that show and aren't on their way out.
func _texts(notices: NoticeStack) -> Array[String]:
	var texts: Array[String] = []
	for notice: Notice in notices.get_notices():
		if not notice.is_leaving():
			texts.append(notice.get_text())
	return texts
