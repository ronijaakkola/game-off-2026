extends GdUnitTestSuite

const SCENE := "res://core/scene_flow/loading_card.tscn"
const LEVEL_1 := "res://shared/level_art/level_1.tres"


# Killed part way, the drop left the button high, and the next drop started from there.
func test_a_level_shown_while_start_drops_in_leaves_the_button_where_it_rests() -> void:
	var runner := scene_runner(SCENE)
	var card := runner.scene() as LoadingCard
	var start := runner.find_child("StartButton") as Button
	var level := load(LEVEL_1) as Level
	card.show_level(level)
	card.show_start()
	await runner.simulate_frames(2)
	var rest := start.position.y
	card.show_level(level)
	card.wait_for_start()
	await runner.simulate_frames(2)
	assert_float(start.position.y).override_failure_message("Not dropping").is_less(rest)

	card.show_level(level)

	assert_float(start.position.y).is_equal(rest)
	assert_float(start.modulate.a).is_equal(1.0)
