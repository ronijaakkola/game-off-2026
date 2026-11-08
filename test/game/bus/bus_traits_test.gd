extends GdUnitTestSuite
## The bus's traits: features it has or doesn't, which stay while any upgrade that added
## them still has them in.

const FORECAST := BusTraits.Type.FUEL_FORECAST


func test_a_trait_added_twice_stays_until_taken_out_twice() -> void:
	var traits := BusTraits.new()
	traits.add(FORECAST)
	traits.add(FORECAST)
	traits.remove(FORECAST)
	assert_bool(traits.has(FORECAST)).is_true()
	traits.remove(FORECAST)
	assert_bool(traits.has(FORECAST)).is_false()


func test_taking_out_a_trait_the_bus_lacks_does_nothing() -> void:
	var traits := BusTraits.new()
	traits.remove(FORECAST)
	traits.add(FORECAST)
	assert_bool(traits.has(FORECAST)).is_true()


func test_changed_is_emitted_only_when_the_trait_comes_or_goes() -> void:
	var traits := BusTraits.new()
	var changes: Array[BusTraits.Type] = []
	traits.changed.connect(func(type: BusTraits.Type) -> void: changes.append(type))

	traits.add(FORECAST)
	traits.add(FORECAST)
	traits.remove(FORECAST)
	assert_array(changes).is_equal([FORECAST])

	traits.remove(FORECAST)
	assert_array(changes).is_equal([FORECAST, FORECAST])
