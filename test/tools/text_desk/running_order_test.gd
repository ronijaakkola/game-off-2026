extends GdUnitTestSuite

const Store := preload("res://tools/text_desk/text_store.gd")
const Order := preload("res://tools/text_desk/running_order.gd")
const Entry := preload("res://tools/text_desk/desk_entry.gd")


# A key the running order names finds no text once its constant, function or node is
# renamed or moved: the order then names the new place.
func test_every_text_it_names_is_in_the_game() -> void:
	var sections := Order.new(Store.new()).build()
	var missing := PackedStringArray()
	for section: Order.Section in sections:
		(
			assert_bool(section.entries.is_empty())
			. override_failure_message("%s has no texts" % section.title)
			. is_false()
		)
		for entry: Entry in section.entries:
			for field: Entry.Field in entry.fields:
				if field.text.missing:
					missing.append("%s: %s %s" % [entry.title, field.text.path, field.text.key])
	(
		assert_array(missing)
		. override_failure_message(
			"tools/text_desk/running_order.gd names texts that are gone:\n" + "\n".join(missing)
		)
		. is_empty()
	)
