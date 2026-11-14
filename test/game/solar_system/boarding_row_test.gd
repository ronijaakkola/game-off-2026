extends GdUnitTestSuite
## A row in the dock panel for one passenger waiting to board.

const ROW := "res://game/solar_system/boarding_row.tscn"

var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	Settings.reduce_motion = false


func after_test() -> void:
	# Assigning re-saves the developer's own settings file with their value.
	Settings.reduce_motion = _reduce_motion


# Feedback's press dip set the beckoning button's scale every frame while it was held, so
# the button shrank under the swell that calls for it to be pressed.
func test_a_beckoning_button_held_down_keeps_its_swell() -> void:
	var row := (load(ROW) as PackedScene).instantiate() as BoardingRow
	add_child(row)
	auto_free(row)
	row.beckoning = true
	var button := row.get_node(^"%BoardButton") as Button

	button.button_down.emit()
	# The dock panel sets the glow every frame of a pulse; this holds it at the height of one.
	for i: int in 5:
		row.beckon_glow = 1.0
		await await_idle_frame()

	assert_vector(button.scale).is_equal(Vector2.ONE * BoardingRow.BECKON_SCALE)
	button.button_up.emit()
