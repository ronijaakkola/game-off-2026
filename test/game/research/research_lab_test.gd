extends GdUnitTestSuite
## Researching from a planet's tree in the solar system: only while the bus is at that
## planet and the player can pay, paying credits and research points from the ledger.
## Clicking an upgrade tile in the planet panel's Research tab researches it.

const SCENE := "res://game/solar_system/solar_system.tscn"

var _runner: GdUnitSceneRunner
var _system: SolarSystem
var _lab: ResearchLab
var _ledger: Ledger
var _ember: Planet
var _tree: ResearchTree


func before_test() -> void:
	_runner = scene_runner(SCENE)
	_system = _runner.scene() as SolarSystem
	(_runner.find_child("WaitingPassengers") as Node).set_process(false)
	_lab = _runner.find_child("ResearchLab") as ResearchLab
	_ledger = _system.get_ledger()
	# The bus starts docked at Ember, which has no tree: give it Frost's.
	_ember = _runner.find_child("Ember") as Planet
	_tree = (_runner.find_child("Frost") as Planet).research_tree
	_ember.research_tree = _tree


func test_researching_at_the_planet_the_bus_is_at_pays_its_cost() -> void:
	var upgrade := _first_upgrade()
	_ledger.credits = upgrade.credits + 7
	for race: Race.Type in upgrade.points:
		_ledger.earn_research(race, upgrade.points[race] + 1)

	_lab.research_at(upgrade, _ember)

	assert_bool(_lab.get_research().is_researched(upgrade)).is_true()
	assert_int(_ledger.credits).is_equal(7)
	for race: Race.Type in upgrade.points:
		assert_int(_ledger.get_research(race)).is_equal(1)
	# Researched already, a second try costs nothing.
	_lab.research_at(upgrade, _ember)
	assert_int(_ledger.credits).is_equal(7)


func test_nothing_is_researched_away_from_the_planet_or_without_the_cost() -> void:
	var upgrade := _first_upgrade()
	var frost := _runner.find_child("Frost") as Planet
	_ledger.credits = upgrade.credits
	for race: Race.Type in upgrade.points:
		_ledger.earn_research(race, upgrade.points[race])

	_lab.research_at(upgrade, frost)
	assert_bool(_lab.get_research().is_researched(upgrade)).is_false()

	_ledger.credits = upgrade.credits - 1
	_lab.research_at(upgrade, _ember)
	assert_bool(_lab.get_research().is_researched(upgrade)).is_false()
	assert_int(_ledger.credits).is_equal(upgrade.credits - 1)
	# The debug panel's way researches from anywhere, still paying.
	_ledger.credits = upgrade.credits
	_lab.research_anywhere(upgrade)
	assert_bool(_lab.get_research().is_researched(upgrade)).is_true()
	assert_int(_ledger.credits).is_equal(0)


func test_clicking_an_upgrade_tile_in_the_research_tab_researches_it() -> void:
	var upgrade := _first_upgrade()
	_ledger.credits = upgrade.credits
	for race: Race.Type in upgrade.points:
		_ledger.earn_research(race, upgrade.points[race])
	_system.open_planet(_ember)
	(_runner.find_child("PlanetPanel") as PlanetPanel).show_tab(PlanetPanel.RESEARCH_TAB)
	# The panel slides in with the camera.
	await await_millis(1000)
	var button := _button_for(upgrade)
	assert_object(button).is_not_null()
	if not button:
		return
	var camera := _runner.find_child("Camera") as Camera3D
	var at := camera.get_viewport().get_final_transform() * button.get_global_rect().get_center()

	_send_click(at)
	await _runner.simulate_frames(2)

	assert_bool(_lab.get_research().is_researched(upgrade)).is_true()
	assert_int(_ledger.credits).is_equal(0)


func _first_upgrade() -> Upgrade:
	for upgrade: Upgrade in _tree.upgrades:
		if upgrade.requires.is_empty():
			return upgrade
	return null


func _button_for(upgrade: Upgrade) -> UpgradeButton:
	for node: Node in _system.find_children("*", "UpgradeButton", true, false):
		var button := node as UpgradeButton
		if button.upgrade == upgrade and button.is_visible_in_tree():
			return button
	return null


# Through Input alone: the runner's own calls reach the scene root's input twice.
func _send_click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
