extends GdUnitTestSuite
## Every kind of quest is in the list a save puts quests back from, each under a kind of its
## own.


func test_every_class_that_extends_quest_is_listed() -> void:
	var listed: Array[String] = []
	for script: GDScript in QuestKinds.ALL:
		listed.append(script.resource_path)
	var missing: Array[String] = []
	for quest_class: Dictionary in _quest_classes():
		if str(quest_class["path"]) not in listed:
			missing.append("%s (%s)" % [quest_class["class"], quest_class["path"]])

	(
		assert_array(missing)
		. override_failure_message(
			(
				(
					"Add %s to QuestKinds.ALL (game/quests/quest_kinds.gd), or a continued run "
					+ "loses a quest of that kind without an error."
				)
				% ", ".join(missing)
			)
		)
		. is_empty()
	)


func test_each_kind_makes_a_quest_of_its_own_class() -> void:
	var kinds: Array[String] = []
	for script: GDScript in QuestKinds.ALL:
		var kind := (script.new() as Quest).get_kind()
		assert_str(kind).is_not_empty()
		assert_array(kinds).not_contains([kind])
		kinds.append(kind)

		assert_object(QuestKinds.make(kind).get_script()).is_same(script)


func test_an_unknown_kind_makes_none() -> void:
	assert_object(QuestKinds.make("")).is_null()
	assert_object(QuestKinds.make("no such quest")).is_null()


# Every global class that extends Quest, at any depth, as the global class list has it.
func _quest_classes() -> Array[Dictionary]:
	var bases: Dictionary[String, String] = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		bases[str(entry["class"])] = str(entry["base"])
	var found: Array[Dictionary] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var base := str(entry["base"])
		while base != "Quest" and bases.has(base):
			base = bases[base]
		if base == "Quest":
			found.append(entry)
	return found
