extends GdUnitTestSuite
## The warp between Lyra's twins, through the dock panel's button: docked at Hither, it reads
## where it goes and its share of a full tank, and pressed it takes that fuel and the bus
## comes out at Yon. With less fuel than that in the tank, it is off and takes nothing.

const SCENE := "res://game/solar_system/solar_system.tscn"


func before() -> void:
	SaveGame.use_test_files("gate_service")


func after() -> void:
	SaveGame.use_player_files()


func test_the_warp_takes_its_share_of_a_full_tank_and_the_bus_comes_out_at_the_twin() -> void:
	var runner := await _docked_at_hither(1.0)
	var tank := (runner.find_child("Bus") as FrameshiftBus).get_fuel_tank()
	var button := runner.find_child("TeleportButton") as Button
	var service := runner.find_child("GateService") as GateService
	var full := tank.capacity
	assert_str(button.text).is_equal(GateService.TEXT % ["Yon", 50])
	assert_bool(button.disabled).is_false()
	monitor_signals(service)

	button.pressed.emit()

	assert_float(tank.fuel).is_equal_approx(full * 0.5, 0.001)
	await assert_signal(service).wait_until(10000).is_emitted("warped")
	var bus := runner.find_child("Bus") as FrameshiftBus
	var yon := runner.find_child("Yon") as Planet
	await assert_func(bus, "get_docked_planet").wait_until(10000).is_equal(yon)


func test_with_less_than_its_share_in_the_tank_the_warp_is_off_and_takes_nothing() -> void:
	var runner := await _docked_at_hither(0.4)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var tank := bus.get_fuel_tank()
	var button := runner.find_child("TeleportButton") as Button
	var fuel := tank.fuel

	assert_bool(button.disabled).is_true()
	button.pressed.emit()
	await runner.simulate_frames(10)

	assert_float(tank.fuel).is_equal(fuel)
	assert_bool((runner.find_child("SystemJump") as SystemJump).is_jumping()).is_false()
	assert_object(bus.get_docked_planet()).is_same(runner.find_child("Hither"))


# A run continued in Lyra, docked at Hither with [param share] of a full tank.
func _docked_at_hither(share: float) -> GdUnitSceneRunner:
	SaveGame.mark_tutorial_done()
	var run := {SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra"), "bus_planet": "Hither"}
	SaveGame.write(run)
	SaveGame.continue_saved()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_object(bus.get_docked_planet()).is_same(runner.find_child("Hither"))
	bus.get_fuel_tank().fuel = share * bus.get_fuel_tank().capacity
	await runner.simulate_frames(2)
	return runner
