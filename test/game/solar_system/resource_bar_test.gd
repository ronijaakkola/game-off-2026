extends GdUnitTestSuite
## The resource bar: credits, research points and the average rating in a pill in the top
## right corner, each counting to its new value, the pill one width whatever they are.

const BAR := preload("res://game/solar_system/resource_bar.tscn")


func test_the_preview_shows_each_bar_count_to_its_values() -> void:
	var runner := scene_runner("res://test/previews/resource_bar_preview.tscn")
	await runner.simulate_frames(5)
	var bars := (runner.find_child("Bars") as VBoxContainer).get_children()
	assert_str(_total(bars[4])).is_equal("12.4k")
	# The payment counts up past 1,000, the bill counts down past it, and 1,000 credits
	# count up from 0.
	await await_millis(1900)
	assert_str(_total(bars[6])).is_equal("1,005")
	assert_str(_total(bars[7])).is_equal("990")
	assert_str(_total(bars[8])).is_equal("1,000")
	# The busy stop's fuel came off, and its two fares counted in once it was over.
	assert_str(_total(bars[0])).is_equal("1,040")


func test_the_bar_keeps_its_width_while_credits_stay_under_1000() -> void:
	var runner := scene_runner("res://test/previews/resource_bar_preview.tscn")
	await runner.simulate_frames(5)
	var bars := (runner.find_child("Bars") as VBoxContainer).get_children()
	# The bar with 40 credits and the one with 990 about to take a payment.
	assert_float((bars[6] as Control).size.x).is_equal((bars[1] as Control).size.x)
	assert_float((bars[1] as Control).size.x).is_equal(264.0)


func test_the_bar_widens_when_the_credits_gain_a_digit() -> void:
	var runner := scene_runner("res://test/previews/resource_bar_preview.tscn")
	await runner.simulate_frames(5)
	var bars := (runner.find_child("Bars") as VBoxContainer).get_children()
	assert_float((bars[2] as Control).size.x).is_greater((bars[1] as Control).size.x)


func _total(bar: Node) -> String:
	return ((bar as ResourceBar).find_child("TotalLabel", true, false) as Label).text


func test_the_credits_slot_holds_three_digits_and_no_more() -> void:
	var bar := auto_free(BAR.instantiate()) as Control
	add_child(bar)
	await await_idle_frame()
	var total := bar.find_child("TotalLabel", true, false) as Label
	var font := total.get_theme_font(&"font")
	var font_size := total.get_theme_font_size(&"font_size")
	var three := font.get_string_size("000", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	assert_float(total.get_combined_minimum_size().x).is_equal_approx(three, 0.5)


func test_every_chip_hangs_at_the_same_height() -> void:
	# The credits' and the rating's hung 2 px higher than the research points', measured
	# from their numbers, which are shorter than the row.
	var bar := auto_free(BAR.instantiate()) as ResourceBar
	add_child(bar)
	bar.ledger = Ledger.new()
	bar.ledger.rate(3.0)
	bar.commit()
	bar.ledger.earn(15)
	bar.ledger.earn_research(Race.Type.BLUE)
	bar.ledger.rate(5.0)
	await await_millis(400)

	var heights: Array[float] = []
	for chip: Node in bar.find_children("*", "ChangeChip", true, false):
		if (chip as ChangeChip).is_showing():
			heights.append((chip as ChangeChip).global_position.y)
	assert_int(heights.size()).is_equal(3)
	assert_float(heights.min()).is_equal(heights.max())
