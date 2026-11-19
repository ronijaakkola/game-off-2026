extends GdUnitTestSuite
## The research points in the resource bar: one count, showing its ledger's.

const SCENE := preload("res://game/solar_system/research_counter.tscn")


func test_a_ledger_given_before_it_is_ready_shows_its_points() -> void:
	# The setter ran before the label existed, so the count stayed at 0.
	var ledger := Ledger.new()
	ledger.earn_research(7)
	var counter: ResearchCounter = auto_free(SCENE.instantiate())
	counter.ledger = ledger

	add_child(counter)

	var counts: Array[String] = []
	var tooltip := counter.get_node(^"Tooltip")
	for label: Node in counter.find_children("*", "Label", true, false):
		if not tooltip.is_ancestor_of(label) and label.get_parent() is not ChangeChip:
			counts.append((label as Label).text)
	assert_array(counts).is_equal(["7"])


func test_points_show_in_a_chip_that_adds_up_and_spending_shows_in_red() -> void:
	var counter: ResearchCounter = auto_free(SCENE.instantiate())
	add_child(counter)
	var chip := counter.find_children("*", "ChangeChip", true, false)[0] as ChangeChip
	var label := chip.find_child("Label", true, false) as Label

	counter.ledger.earn_research()
	counter.ledger.earn_research()

	assert_str(label.text).is_equal("+2")
	assert_that(label.get_theme_color(&"font_color")).is_equal(ResearchCounter.COLOR)
	counter.ledger.spend_research(2)
	assert_str(label.text).is_equal("-2")
	assert_that(label.get_theme_color(&"font_color")).is_equal(ChangeChip.LOSS_COLOR)
