extends GdUnitTestSuite
## The resource bar: credits, research points and the average rating in a pill in the top
## right corner, each counting to its new value.


func test_the_preview_shows_each_bar_count_to_its_values() -> void:
	var runner := scene_runner("res://test/previews/resource_bar_preview.tscn")
	await runner.simulate_frames(5)
	var bars := (runner.find_child("Bars") as VBoxContainer).get_children()
	assert_str(_total(bars[3])).is_equal("12,480")
	# The payment counts up past 1,000, the bill counts down past it, and 1,000 credits
	# count up from 0.
	await await_millis(1900)
	assert_str(_total(bars[5])).is_equal("1,005")
	assert_str(_total(bars[6])).is_equal("990")
	assert_str(_total(bars[7])).is_equal("1,000")


func _total(bar: Node) -> String:
	return ((bar as ResourceBar).get_credits().find_child("TotalLabel") as Label).text
