extends GdUnitTestSuite

var _field: PhaseField


func before_test() -> void:
	# An empty field with the ship in the bottom-left corner.
	_field = PhaseField.new()
	_field.ship = Vector2i(0, 7)


func test_phase_cruises_to_the_first_item_and_stops_after_the_run() -> void:
	_field.set_item(Vector2i(2, 7), PhaseField.Item.SCRAP)
	_field.set_item(Vector2i(3, 7), PhaseField.Item.CRYSTAL)
	_field.set_item(Vector2i(5, 7), PhaseField.Item.SCRAP)
	var steps := _field.phase(Vector2i.RIGHT)
	assert_array(_cells_of(steps)).is_equal(
		[Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7)]
	)
	assert_that(_field.ship).is_equal(Vector2i(4, 7))
	assert_int(_field.get_item(Vector2i(3, 7))).is_equal(PhaseField.Item.NONE)
	# The scrap past the gap is still there.
	assert_int(_field.get_item(Vector2i(5, 7))).is_equal(PhaseField.Item.SCRAP)
	assert_int(_field.score).is_equal(70)
	assert_int(_field.fuel).is_equal(PhaseField.START_FUEL - 1)


func test_phase_wraps_round_the_edge() -> void:
	_field.set_item(Vector2i(0, 0), PhaseField.Item.SCRAP)
	_field.phase(Vector2i.DOWN)
	assert_that(_field.ship).is_equal(Vector2i(0, 1))


func test_a_line_with_nothing_on_it_cant_be_phased() -> void:
	assert_array(_field.phase(Vector2i.UP)).is_empty()
	assert_int(_field.fuel).is_equal(PhaseField.START_FUEL)
	assert_that(_field.ship).is_equal(Vector2i(0, 7))


func test_a_full_line_brings_the_ship_back_to_its_cell() -> void:
	for column: int in range(1, PhaseField.SIZE):
		_field.set_item(Vector2i(column, 7), PhaseField.Item.SCRAP)
	var steps := _field.phase(Vector2i.LEFT)
	assert_int(steps.size()).is_equal(PhaseField.SIZE)
	assert_that(_field.ship).is_equal(Vector2i(0, 7))


func test_a_rock_costs_hull_and_breaks_the_combo() -> void:
	_field.set_item(Vector2i(1, 7), PhaseField.Item.SCRAP)
	_field.phase(Vector2i.RIGHT)
	_field.set_item(Vector2i(3, 7), PhaseField.Item.ROCK)
	_field.phase(Vector2i.RIGHT)
	assert_int(_field.hull).is_equal(PhaseField.START_HULL - 1)
	assert_int(_field.combo).is_equal(0)
	assert_int(_field.best_combo).is_equal(1)


func test_clean_phases_in_a_row_build_a_combo_with_bonus_points() -> void:
	_field.set_item(Vector2i(1, 7), PhaseField.Item.SCRAP)
	_field.set_item(Vector2i(3, 7), PhaseField.Item.SCRAP)
	_field.phase(Vector2i.RIGHT)
	_field.phase(Vector2i.RIGHT)
	assert_int(_field.combo).is_equal(2)
	assert_int(_field.score).is_equal(20 + 20 + 2 * PhaseField.COMBO_POINTS)


func test_the_last_hull_point_ends_the_phase_on_the_rock() -> void:
	_field.hull = 1
	_field.set_item(Vector2i(1, 7), PhaseField.Item.ROCK)
	_field.set_item(Vector2i(2, 7), PhaseField.Item.SCRAP)
	_field.phase(Vector2i.RIGHT)
	assert_that(_field.ship).is_equal(Vector2i(1, 7))
	assert_int(_field.get_item(Vector2i(2, 7))).is_equal(PhaseField.Item.SCRAP)
	assert_bool(_field.is_over()).is_true()


func test_fuel_ore_refuels_up_to_the_tank() -> void:
	_field.fuel = 10
	_field.set_item(Vector2i(1, 7), PhaseField.Item.FUEL)
	_field.phase(Vector2i.RIGHT)
	assert_int(_field.fuel).is_equal(10 - 1 + PhaseField.FUEL_ORE)


func test_a_slide_wraps_its_line_carries_the_ship_and_costs_fuel_per_cell() -> void:
	_field.set_item(Vector2i(7, 7), PhaseField.Item.CRYSTAL)
	assert_bool(_field.slide(true, 7, 2)).is_true()
	assert_int(_field.get_item(Vector2i(1, 7))).is_equal(PhaseField.Item.CRYSTAL)
	assert_that(_field.ship).is_equal(Vector2i(2, 7))
	assert_int(_field.fuel).is_equal(PhaseField.START_FUEL - 2)


func test_a_slide_goes_the_short_way_round() -> void:
	_field.set_item(Vector2i(0, 3), PhaseField.Item.ROCK)
	assert_bool(_field.slide(false, 0, 7)).is_true()
	assert_int(_field.get_item(Vector2i(0, 2))).is_equal(PhaseField.Item.ROCK)
	assert_int(_field.fuel).is_equal(PhaseField.START_FUEL - 1)


func test_a_slide_breaks_the_combo() -> void:
	_field.combo = 3
	_field.slide(true, 2, 1)
	assert_int(_field.combo).is_equal(0)


func test_a_slide_costing_more_than_the_fuel_left_is_refused() -> void:
	_field.fuel = 2
	_field.set_item(Vector2i(5, 7), PhaseField.Item.SCRAP)
	assert_bool(_field.slide(true, 7, 3)).is_false()
	assert_int(_field.get_item(Vector2i(5, 7))).is_equal(PhaseField.Item.SCRAP)
	assert_int(_field.fuel).is_equal(2)


func test_a_generated_field_leaves_every_line_a_place_to_stop() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 20:
		rng.seed = seed_value
		_field.reset(rng)
		assert_int(_field.get_item(_field.ship)).is_equal(PhaseField.Item.NONE)
		for line: int in PhaseField.SIZE:
			assert_bool(_has_open_cell(Vector2i(0, line), Vector2i.RIGHT)).is_true()
			assert_bool(_has_open_cell(Vector2i(line, 0), Vector2i.DOWN)).is_true()


func _has_open_cell(start: Vector2i, step: Vector2i) -> bool:
	for i: int in PhaseField.SIZE:
		var cell := start + step * i
		if cell != _field.ship and _field.get_item(cell) == PhaseField.Item.NONE:
			return true
	return false


func _cells_of(steps: Array[Dictionary]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for step: Dictionary in steps:
		cells.append(step.cell)
	return cells
