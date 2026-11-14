extends GdUnitTestSuite
## The research points in the resource bar: a count per race, showing its ledger's.

const SCENE := preload("res://game/solar_system/research_counter.tscn")


func test_a_ledger_given_before_it_is_ready_shows_its_points() -> void:
	# The setter ran before the labels existed, so the counts stayed at 0.
	var ledger := Ledger.new()
	ledger.earn_research(Race.Type.ORANGE, 7)
	var counter: ResearchCounter = auto_free(SCENE.instantiate())
	counter.ledger = ledger

	add_child(counter)

	var counts: Array[String] = []
	var tooltip := counter.get_node(^"Tooltip")
	for label: Node in counter.find_children("*", "Label", true, false):
		if not tooltip.is_ancestor_of(label):
			counts.append((label as Label).text)
	assert_array(counts).is_equal(["0", "0", "7"])


func test_the_races_show_in_the_research_trees_order() -> void:
	# The chips went in the enum's order, blue, orange, green, while the trees go blue,
	# green, orange.
	var counter: ResearchCounter = auto_free(SCENE.instantiate())
	add_child(counter)

	var colors: Array[Color] = []
	for icon: Node in counter.find_children("*", "TextureRect", true, false):
		colors.append((icon as TextureRect).self_modulate)
	(
		assert_array(colors)
		. is_equal(
			[
				Race.SKIN_COLORS[Race.Type.BLUE],
				Race.SKIN_COLORS[Race.Type.GREEN],
				Race.SKIN_COLORS[Race.Type.ORANGE],
			]
		)
	)
