extends GdUnitTestSuite
## Researching in the solar system: the research screen opens on every tree from the dock
## panel's Research button and pauses the game, holding an upgrade's tile researches it,
## paying credits and research points from the ledger, and nothing is researched without
## the cost or in a stage that isn't open. The pause menu opened over the screen takes Esc,
## and closing it leaves the game paused under the screen. The dock panel's Research button
## glows while the player can pay for an upgrade, and not while they can't.

const SCENE := "res://game/solar_system/solar_system.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

var _runner: GdUnitSceneRunner
var _system: SolarSystem
var _lab: ResearchLab
var _ledger: Ledger


func before_test() -> void:
	_runner = scene_runner(SCENE)
	_system = _runner.scene() as SolarSystem
	(_runner.find_child("WaitingPassengers") as Node).set_process(false)
	_lab = _runner.find_child("ResearchLab") as ResearchLab
	_ledger = _system.get_ledger()


func after_test() -> void:
	_system.get_tree().paused = false


func test_researching_an_upgrade_pays_its_cost() -> void:
	var upgrade := _first_upgrade()
	_pay_for(upgrade, 7)

	_lab.research(upgrade)

	assert_bool(_lab.get_research().is_researched(upgrade)).is_true()
	assert_int(_ledger.credits).is_equal(7)
	for race: Race.Type in upgrade.points:
		assert_int(_ledger.get_research(race)).is_equal(1)
	# Researched already, a second try costs nothing.
	_lab.research(upgrade)
	assert_int(_ledger.credits).is_equal(7)


func test_nothing_is_researched_without_the_cost_or_the_promotion() -> void:
	var upgrade := _first_upgrade()
	_pay_for(upgrade, 0)
	_ledger.credits = upgrade.credits - 1
	_lab.research(upgrade)
	assert_bool(_lab.get_research().is_researched(upgrade)).is_false()
	assert_int(_ledger.credits).is_equal(upgrade.credits - 1)

	var sealed := _upgrade_in_stage(1)
	for required: Upgrade in _all_required(sealed):
		_lab.get_research().research(required)
	_pay_for(sealed, 0)
	_lab.research(sealed)
	assert_bool(_lab.get_research().is_researched(sealed)).is_false()
	_lab.get_research().open_next_stage()
	_lab.research(sealed)
	assert_bool(_lab.get_research().is_researched(sealed)).is_true()


func test_the_research_button_opens_the_screen_and_pauses_the_game() -> void:
	var dock := _runner.find_child("DockPanel") as DockPanel
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen

	dock.research_pressed.emit(dock.planet)

	assert_bool(screen.is_open()).is_true()
	assert_bool(_system.get_tree().paused).is_true()
	screen.close()
	assert_bool(_system.get_tree().paused).is_false()


func test_the_research_button_glows_while_an_upgrade_can_be_paid_for() -> void:
	var dock := _runner.find_child("DockPanel") as DockPanel
	(_runner.find_child("Bus") as FrameshiftBus).get_docked_planet().has_lab = true
	_ledger.credits = 0

	await _runner.simulate_frames(1)
	assert_bool(_lab.can_research_any()).is_false()
	assert_bool(dock.is_research_glowing()).is_false()

	_pay_for(_first_upgrade(), 0)
	await _runner.simulate_frames(1)
	assert_bool(_lab.can_research_any()).is_true()
	assert_bool(dock.is_research_glowing()).is_true()


func test_the_pause_menu_over_the_screen_leaves_the_game_paused() -> void:
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen
	var menu := _runner.find_child("PauseMenu") as PauseMenu
	_lab.open_screen()
	var tree := _system.get_tree()

	# As leaving browser fullscreen does on the web.
	menu.open()
	_send_pause()
	await tree.process_frame
	assert_bool(menu.visible).is_false()
	assert_bool(screen.is_open()).is_true()
	assert_bool(tree.paused).is_true()

	menu.open()
	menu.close()
	assert_bool(tree.paused).is_true()
	_send_pause()
	await tree.process_frame
	assert_bool(screen.is_open()).is_false()
	assert_bool(tree.paused).is_false()


func test_nothing_is_researched_without_a_hold() -> void:
	var upgrade := _first_upgrade()
	_pay_for(upgrade, 0)
	_lab.open_screen()
	var tree := _system.get_tree()
	var deadline := Time.get_ticks_msec() + int(UpgradeButton.HOLD_SECONDS * 2000.0)
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame

	assert_bool(_lab.get_research().is_researched(upgrade)).is_false()
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen
	assert_float(screen.get_button(upgrade).get_hold_progress()).is_equal(0.0)


func test_an_upgrade_tile_shows_its_tooltip_at_once() -> void:
	var upgrade := _first_upgrade()
	_pay_for(upgrade, 0)
	_lab.open_screen()
	var tree := _system.get_tree()
	await tree.process_frame
	var button := (_runner.find_child("ResearchScreen") as ResearchScreen).get_button(upgrade)
	var tooltip := button.get_info_tooltip()

	button.mouse_entered.emit()
	await tree.process_frame

	assert_bool(tooltip.visible).is_true()
	assert_str(tooltip.title).is_equal(upgrade.title)
	assert_str(tooltip.sentence).is_equal(upgrade.description)
	assert_object(tooltip.extra).is_not_null()
	var notes := tooltip.extra.find_children("*", "Label", true, false)
	var texts := notes.map(func(label: Node) -> String: return (label as Label).text)
	assert_array(texts).not_contains([UpgradeTooltip.LACKING_TEXT])


func test_holding_an_upgrade_tile_researches_it() -> void:
	var upgrade := _first_upgrade()
	_pay_for(upgrade, 0)
	_lab.open_screen()
	# The game is paused under the screen, and the runner's frames wait on Timers that stop.
	var tree := _system.get_tree()
	await tree.process_frame
	await tree.process_frame
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen
	var button := screen.get_button(upgrade)
	assert_object(button).is_not_null()
	if not button:
		return
	var camera := _runner.find_child("Camera") as Camera3D
	var at := camera.get_viewport().get_final_transform() * button.get_global_rect().get_center()

	_send_press(at, true)
	await tree.process_frame
	await tree.process_frame
	assert_bool(_lab.get_research().is_researched(upgrade)).is_false()
	assert_float(button.get_hold_progress()).is_greater(0.0)
	var held := await PauseProofWait.for_signal(button.held, 2000)
	_send_press(at, false)

	assert_bool(held).is_true()
	assert_bool(_lab.get_research().is_researched(upgrade)).is_true()
	assert_int(_ledger.credits).is_equal(0)


func test_the_screens_bar_shows_the_fares_the_huds_bar_shows() -> void:
	var hud_bar := _runner.find_child("TopCentre").find_child("ResourceBar") as ResourceBar
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen
	var screen_bar := screen.find_child("ResourceBar") as ResourceBar
	_ledger.credits = 0
	_ledger.earn(119)
	_ledger.rate(4.0)

	# As when everyone going to the planet has got off.
	(_runner.find_child("Cabin") as Cabin).unloaded.emit()
	await await_millis(1900)

	assert_str(_shown(hud_bar, "TotalLabel")).is_equal("119")
	assert_str(_shown(screen_bar, "TotalLabel")).is_equal("119")
	assert_str(_shown(hud_bar, "AverageLabel")).is_not_equal(RatingCounter.NO_RATING)
	assert_str(_shown(screen_bar, "AverageLabel")).is_equal(_shown(hud_bar, "AverageLabel"))


func _shown(bar: ResourceBar, label: String) -> String:
	return (bar.find_child(label, true, false) as Label).text


func _first_upgrade() -> Upgrade:
	for upgrade: Upgrade in _lab.trees[0].upgrades:
		if upgrade.requires.is_empty():
			return upgrade
	return null


func _upgrade_in_stage(stage: int) -> Upgrade:
	for upgrade: Upgrade in _lab.trees[0].upgrades:
		if Research.get_stage(upgrade) == stage:
			return upgrade
	return null


# Everything [param upgrade] needs first, all the way up its tree.
func _all_required(upgrade: Upgrade) -> Array[Upgrade]:
	var found: Array[Upgrade] = []
	for required: Upgrade in upgrade.requires:
		for deeper: Upgrade in _all_required(required):
			if deeper not in found:
				found.append(deeper)
		if required not in found:
			found.append(required)
	return found


# Gives the player what [param upgrade] costs, with [param spare] credits over.
func _pay_for(upgrade: Upgrade, spare: int) -> void:
	_ledger.credits = upgrade.credits + spare
	for race: Race.Type in upgrade.points:
		_ledger.earn_research(race, upgrade.points[race] + (1 if spare > 0 else 0))


# Esc, the pause action, through Input as a key press would come.
func _send_pause() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# Through Input alone: the runner's own calls reach the scene root's input twice.
func _send_press(at: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
