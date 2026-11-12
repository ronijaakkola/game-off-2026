extends GdUnitTestSuite
## Which upgrades show how in their tree, and what researching one does to the bus, through
## Research's and Upgrade's public calls.

var _stats: BusStats
var _research: Research


func before_test() -> void:
	_stats = BusStats.new()
	_research = Research.new(_stats)


func test_an_upgrade_is_available_once_everything_it_requires_is_researched() -> void:
	var first := _upgrade()
	var second := _upgrade()
	var third := _upgrade([first, second])

	assert_int(_state(third)).is_equal(Research.State.LOCKED)
	_research.research(first)
	assert_int(_state(third)).is_equal(Research.State.LOCKED)
	_research.research(second)
	assert_int(_state(third)).is_equal(Research.State.AVAILABLE)
	_research.research(third)
	assert_int(_state(third)).is_equal(Research.State.RESEARCHED)


func test_a_hidden_upgrade_shows_as_hidden_only_until_it_is_unlocked() -> void:
	var first := _upgrade()
	var secret := _upgrade([first])
	secret.hidden = true

	assert_int(_state(secret)).is_equal(Research.State.HIDDEN)
	_research.research(first)
	assert_int(_state(secret)).is_equal(Research.State.AVAILABLE)


func test_an_upgrade_the_player_cannot_pay_for_is_unaffordable() -> void:
	var upgrade := _upgrade([], 20, {Race.Type.BLUE: 3})
	var blue_3: Dictionary[Race.Type, int] = {Race.Type.BLUE: 3}
	var blue_2: Dictionary[Race.Type, int] = {Race.Type.BLUE: 2}
	var other_race: Dictionary[Race.Type, int] = {Race.Type.GREEN: 10}

	assert_int(_research.get_state(upgrade, 20, blue_3)).is_equal(Research.State.AVAILABLE)
	assert_int(_research.get_state(upgrade, 19, blue_3)).is_equal(Research.State.UNAFFORDABLE)
	assert_int(_research.get_state(upgrade, 20, blue_2)).is_equal(Research.State.UNAFFORDABLE)
	assert_int(_research.get_state(upgrade, 99, other_race)).is_equal(Research.State.UNAFFORDABLE)


func test_researching_puts_its_modifiers_and_traits_on_the_bus_once() -> void:
	var speed := _stats.get_stat(BusStats.Type.MAX_SPEED)
	speed.base = 10.0
	var upgrade := _upgrade()
	upgrade.modifiers = [StatModifier.new(BusStats.Type.MAX_SPEED, StatModifier.Kind.FLAT, 5.0)]
	upgrade.traits = [BusTraits.Type.PILLOWS]
	monitor_signals(_research)

	_research.research(upgrade)
	_research.research(upgrade)

	assert_float(speed.get_value()).is_equal_approx(15.0, 0.001)
	assert_bool(_stats.get_traits().has(BusTraits.Type.PILLOWS)).is_true()
	assert_bool(_research.is_researched(upgrade)).is_true()
	await assert_signal(_research).is_emitted("researched", [upgrade])
	# The second call changed nothing, so taking the trait out once leaves the bus without it.
	_stats.get_traits().remove(BusTraits.Type.PILLOWS)
	assert_bool(_stats.get_traits().has(BusTraits.Type.PILLOWS)).is_false()


func test_an_upgrade_past_the_open_stages_needs_a_promotion() -> void:
	var first := _upgrade()
	var second := _upgrade([first])
	second.tier = Research.ROWS_PER_STAGE
	var last := _upgrade([first])
	last.tier = Research.ROWS_PER_STAGE * Research.STAGES + 3
	_research.research(first)

	assert_int(Research.get_stage(last)).is_equal(Research.STAGES - 1)
	assert_int(_state(second)).is_equal(Research.State.NEEDS_PROMOTION)
	_research.open_next_stage()
	assert_int(_state(second)).is_equal(Research.State.AVAILABLE)
	assert_int(_state(last)).is_equal(Research.State.NEEDS_PROMOTION)
	_research.open_next_stage()
	_research.open_next_stage()
	assert_bool(_research.is_stage_open(Research.STAGES - 1)).is_true()
	assert_bool(_research.is_stage_open(Research.STAGES)).is_false()
	assert_int(_state(last)).is_equal(Research.State.AVAILABLE)


func test_an_upgrade_takes_the_colours_of_the_race_it_costs_most() -> void:
	assert_int(_upgrade([], 0, {Race.Type.GREEN: 1, Race.Type.ORANGE: 4}).get_race()).is_equal(
		Race.Type.ORANGE
	)
	# A tie goes to the first race.
	assert_int(_upgrade([], 0, {Race.Type.ORANGE: 2, Race.Type.BLUE: 2}).get_race()).is_equal(
		Race.Type.BLUE
	)


# The state of [param upgrade] for a player with plenty to pay with.
func _state(upgrade: Upgrade) -> Research.State:
	var points: Dictionary[Race.Type, int] = {}
	for value: int in Race.Type.values():
		points[value as Race.Type] = 1000
	return _research.get_state(upgrade, 1000, points)


func _upgrade(
	requires: Array[Upgrade] = [], credits := 0, points: Dictionary[Race.Type, int] = {}
) -> Upgrade:
	var upgrade := Upgrade.new()
	upgrade.requires.assign(requires)
	upgrade.credits = credits
	upgrade.points = points
	return upgrade
