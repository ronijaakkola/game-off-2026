extends GdUnitTestSuite
## What the station panel holds back while the tutorial asks it to: a fuel button that
## shows but is off, and no Board all.

const SCENE := "res://game/solar_system/dock_panel.tscn"


func test_a_locked_fuel_button_is_off_even_when_fuel_can_be_bought() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as DockPanel
	var button := runner.find_child("FuelButton") as BaseButton

	panel.fuel_locked = true
	panel.show_fuel(0.5, 8, true, "")
	assert_bool(button.disabled).is_true()

	panel.fuel_locked = false
	panel.show_fuel(0.5, 8, true, "")
	assert_bool(button.disabled).is_false()


func test_board_all_hides_while_asked_to() -> void:
	var runner := scene_runner(SCENE)
	var board_all := runner.find_child("BoardAllButton") as Control

	runner.set_property("board_all_hidden", true)
	assert_bool(board_all.visible).is_false()
	runner.set_property("board_all_hidden", false)
	assert_bool(board_all.visible).is_true()
