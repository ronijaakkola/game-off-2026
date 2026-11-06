extends GdUnitTestSuite
## The Commuter's data survives saving: `check.py ids` once dropped its string lists.

const COMMUTER := "res://game/passengers/types/commuter.tres"


func test_has_names_lines_and_needs() -> void:
	var kind := load(COMMUTER) as PassengerType
	assert_int(kind.names.size()).is_greater(1)
	assert_int(kind.idle_lines.size()).is_greater(1)
	assert_int(kind.needs.size()).is_greater(0)
