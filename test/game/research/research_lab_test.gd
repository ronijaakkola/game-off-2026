extends GdUnitTestSuite
## Researching in the solar system: the research screen opens on every tree from the dock
## panel's Research button and pauses the game, holding an upgrade's tile researches it,
## paying credits and research points from the ledger, and nothing is researched without
## the cost or in a stage that isn't open. The pause menu opened over the screen takes Esc,
## and closing it leaves the game paused under the screen. The dock panel's Research button
## is outlined while the player can pay for an upgrade they couldn't when they last closed
## the screen, and not while they can't, nor for the same ones or fewer. The green tree's
## third stage: the Bottomless complaints box comes and goes on the ledger with its trait, the
## Remote terminal researches where there is no lab and takes the lab badges away, even
## ones made after it, and the Research grant's buttons trade research points and credits
## both ways while the player has what they give.

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
	# As the mechanic's first call does: research opens, and the Research button shows.
	_lab.get_research().open()
	(_runner.find_child("DockPanel") as DockPanel).research_hidden = false


func after_test() -> void:
	_system.get_tree().paused = false


func test_researching_an_upgrade_pays_its_cost() -> void:
	var upgrade := _first_upgrade()
	_pay_for(upgrade, 7)

	_lab.research(upgrade)

	assert_bool(_lab.get_research().is_researched(upgrade)).is_true()
	assert_int(_ledger.credits).is_equal(7)
	assert_int(_ledger.get_research()).is_equal(1)
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


func test_the_research_button_is_outlined_while_an_upgrade_can_be_paid_for() -> void:
	var dock := _runner.find_child("DockPanel") as DockPanel
	(_runner.find_child("Bus") as FrameshiftBus).get_docked_planet().has_lab = true
	_ledger.credits = 0

	await _runner.simulate_frames(1)
	assert_bool(_lab.has_unseen_upgrade()).is_false()
	assert_bool(dock.is_research_nudging()).is_false()

	_pay_for(_first_upgrade(), 0)
	await _runner.simulate_frames(1)
	assert_bool(_lab.has_unseen_upgrade()).is_true()
	assert_bool(dock.is_research_nudging()).is_true()


func test_the_research_button_is_not_outlined_for_upgrades_already_seen() -> void:
	var dock := _runner.find_child("DockPanel") as DockPanel
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen
	(_runner.find_child("Bus") as FrameshiftBus).get_docked_planet().has_lab = true
	_pay_for(_first_upgrade(), 0)
	var credits := _ledger.credits
	_lab.open_screen()
	screen.close()
	await _runner.simulate_frames(1)
	assert_bool(dock.is_research_nudging()).is_false()

	# Fewer to pay for, then the same ones again: nothing new to see.
	_ledger.credits = 0
	await _runner.simulate_frames(1)
	assert_bool(dock.is_research_nudging()).is_false()
	_ledger.credits = credits
	await _runner.simulate_frames(1)
	assert_bool(dock.is_research_nudging()).is_false()

	# More of them: what the first upgrade opens, and enough to pay for it.
	_lab.get_research().research(_first_upgrade())
	_ledger.credits = 100000
	_ledger.earn_research(300)
	await _runner.simulate_frames(1)
	assert_bool(dock.is_research_nudging()).is_true()


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
	_ledger.earn_research(upgrade.points + (1 if spare > 0 else 0))


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


func test_the_complaints_box_comes_and_goes_with_its_trait() -> void:
	var traits := (_runner.find_child("Bus") as FrameshiftBus).get_stats().get_traits()
	assert_bool(_ledger.complaints_box).is_false()

	traits.add(BusTraits.Type.COMPLAINTS_BOX)
	assert_bool(_ledger.complaints_box).is_true()
	traits.remove(BusTraits.Type.COMPLAINTS_BOX)
	assert_bool(_ledger.complaints_box).is_false()


func test_the_remote_terminal_researches_at_a_planet_with_no_lab() -> void:
	var traits := (_runner.find_child("Bus") as FrameshiftBus).get_stats().get_traits()
	var no_lab := _planet_without_lab()
	assert_bool(_lab.can_research_at(no_lab)).is_false()

	traits.add(BusTraits.Type.REMOTE_TERMINAL)

	assert_bool(_lab.can_research_at(no_lab)).is_true()


func test_the_research_grant_trades_research_points_and_credits_both_ways() -> void:
	var traits := (_runner.find_child("Bus") as FrameshiftBus).get_stats().get_traits()
	var screen := _runner.find_child("ResearchScreen") as ResearchScreen
	var buy := screen.find_child("BuyPointButton") as Button
	var sell := screen.find_child("SellPointButton") as Button
	var price := ResearchLab.POINT_PRICE
	_ledger.credits = price * 2 + 50
	var points := _ledger.get_research()
	# Without the grant there are no buttons, and nothing to trade.
	_lab.open_screen()
	assert_bool(buy.visible or sell.visible).is_false()
	_lab.buy_point()
	_lab.sell_point()
	assert_int(_ledger.credits).is_equal(price * 2 + 50)

	traits.add(BusTraits.Type.RESEARCH_GRANT)
	assert_bool(buy.visible and sell.visible).is_true()
	buy.pressed.emit()
	buy.pressed.emit()
	# Short of the price, it sells nothing, and the button is off.
	buy.pressed.emit()
	assert_int(_ledger.credits).is_equal(50)
	assert_int(_ledger.get_research()).is_equal(points + 2)
	await _runner.simulate_frames(2)
	assert_bool(buy.disabled).is_true()

	for i: int in points + 2:
		sell.pressed.emit()
	# With no point left, it buys none, and the button is off.
	sell.pressed.emit()
	assert_int(_ledger.get_research()).is_equal(0)
	assert_int(_ledger.credits).is_equal(50 + price * (points + 2))
	await _runner.simulate_frames(2)
	assert_bool(sell.disabled).is_true()
	assert_bool(buy.disabled).is_false()
	screen.close()


func _planet_without_lab() -> Planet:
	for node: Node in _system.find_children("*", "", true, false):
		var planet := node as Planet
		if planet and not planet.has_lab:
			return planet
	return null


func test_the_remote_terminal_takes_the_lab_badges_away() -> void:
	var traits := (_runner.find_child("Bus") as FrameshiftBus).get_stats().get_traits()
	var badges := _runner.find_child("LabBadges") as LabBadges
	var lab := _planet_with_lab()
	await _runner.simulate_frames(2)
	assert_bool(badges.is_shown(lab)).is_true()

	traits.add(BusTraits.Type.REMOTE_TERMINAL)
	await await_millis(int(LabBadges.POP_SECONDS * 1000) + 200)

	assert_bool(badges.is_shown(lab)).is_false()
	traits.remove(BusTraits.Type.REMOTE_TERMINAL)
	await _runner.simulate_frames(2)
	assert_bool(badges.is_shown(lab)).is_true()


func _planet_with_lab() -> Planet:
	for node: Node in _system.find_children("*", "", true, false):
		var planet := node as Planet
		if planet and planet.has_lab:
			return planet
	return null


func test_lab_badges_made_after_the_remote_terminal_stay_away() -> void:
	var traits := (_runner.find_child("Bus") as FrameshiftBus).get_stats().get_traits()
	var badges := _runner.find_child("LabBadges") as LabBadges
	var lab := _planet_with_lab()
	traits.add(BusTraits.Type.REMOTE_TERMINAL)
	await await_millis(int(LabBadges.POP_SECONDS * 1000) + 200)

	# As in a continued run, where the badges are made after the upgrades are back, and as
	# a mechanic's call pops one in.
	var planets: Array[Planet] = [lab]
	badges.set_planets(planets)
	badges.pop_in(lab)
	await _runner.simulate_frames(2)

	assert_bool(badges.is_shown(lab)).is_false()
