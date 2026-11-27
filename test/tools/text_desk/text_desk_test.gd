extends GdUnitTestSuite

const SCENE := "res://tools/text_desk/text_desk.tscn"
const Desk := preload("res://tools/text_desk/text_desk.gd")


# Nothing is saved here, so no file of the game changes.
func test_typing_in_a_part_changes_the_text_in_the_game() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(40)
	var desk := runner.find_child("Desk") as Desk
	desk._filter.text = "Your bus"
	desk._list()
	desk._open(desk._listed[0])
	await runner.simulate_frames(5)
	var title := desk._fields.get_child(1) as TextEdit
	title.text = "My bus"
	title.text_changed.emit()
	await runner.simulate_frames(20)
	var shown := false
	for card: Node in runner.scene().find_children("*", "PanelContainer", true, false):
		shown = shown or (card is GuideCard and (card as GuideCard).title == "My bus")
	assert_bool(shown).override_failure_message("No guide card says My bus").is_true()
	assert_str(desk._save.text).is_equal("Save 1")
	assert_bool(desk._save.disabled).is_false()
