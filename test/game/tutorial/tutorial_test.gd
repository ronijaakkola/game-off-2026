extends GdUnitTestSuite
## A new run opens on the boss's call with only the bus bars showing; answering it with
## either of the two answers starts the steps on the guide card beside the bus. Skipping the
## tutorial puts back every rule it changed.

const SCENE := "res://game/solar_system/solar_system.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")
# The suite saves to a file of its own, never the player's.
const TEST_SAVE := "user://test_tutorial_save.json"

var _window_size: Vector2i


func before() -> void:
	SaveGame.path = TEST_SAVE
	# Headless, the window is 64×64 and the canvas_items stretch would scale every click.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	SaveGame.delete()
	SaveGame.path = SaveGame.PATH
	get_tree().root.size = _window_size


func after_test() -> void:
	get_tree().paused = false


func test_a_new_run_opens_on_the_call_and_answering_it_starts_the_steps() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	assert_bool((runner.find_child("PassengerPanel") as Control).visible).is_false()
	assert_bool((runner.find_child("TopRight") as Control).visible).is_false()
	assert_bool((runner.find_child("BusStatusPanel") as Control).visible).is_true()

	# Once the screen has faded in, the call comes.
	var notices := runner.find_child("Notices") as NoticeStack
	await assert_func(self, "_has_notice", [notices]).wait_until(5000).is_true()
	await runner.simulate_frames(30)
	_click(runner, notices.get_notices()[0].find_child("ActionButton") as Control)
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	panel.skip()
	await runner.simulate_frames(60)
	assert_str((panel.find_child("CallerName") as Label).text).is_equal("Your Boss")

	# Either answer goes on.
	_click(runner, panel.find_child("DeclineButton") as Control)
	var answered := await PauseProofWait.for_signal(panel.answered, 3000)
	assert_bool(answered).override_failure_message("The call never closed").is_true()
	if is_failure():
		return
	var guide := runner.find_child("GuideCard") as GuideCard
	await assert_func(guide, "is_visible_in_tree").wait_until(2000).is_true()
	assert_str(guide.text).starts_with("You are driving this bus.")


func test_skipping_puts_back_what_it_changed() -> void:
	SaveGame.start_new()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var moon := runner.find_child("Moon") as Planet
	var lab := runner.find_child("ResearchLab") as ResearchLab
	var fuel_tank := _fuel_tank(lab)
	assert_float(moon.fuel_price).is_zero()
	assert_int(fuel_tank.points.get(Race.Type.BLUE, 0)).is_equal(1)

	(runner.find_child("Tutorial") as Tutorial).skip()

	assert_float(moon.fuel_price).is_greater(0.0)
	assert_int(fuel_tank.points.get(Race.Type.BLUE, 0)).is_equal(2)
	assert_bool(lab.restricted).is_false()
	assert_bool((runner.find_child("PassengerPanel") as PassengerPanel).kicks_allowed).is_true()
	var dock := runner.find_child("DockPanel") as DockPanel
	assert_bool(dock.fuel_hidden or dock.fuel_locked or dock.board_all_hidden).is_false()
	assert_bool((runner.find_child("BusStatusPanel") as BusStatusPanel).stop_locked).is_false()


func _has_notice(notices: NoticeStack) -> bool:
	return not notices.get_notices().is_empty()


func _click(runner: GdUnitSceneRunner, control: Control) -> void:
	runner.set_mouse_position(control.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _fuel_tank(lab: ResearchLab) -> Upgrade:
	for tree: ResearchTree in lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			if upgrade.title == TutorialRules.FUEL_TANK:
				return upgrade
	return null
