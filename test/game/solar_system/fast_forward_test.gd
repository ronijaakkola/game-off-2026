extends GdUnitTestSuite
## The debug panel's Fast-forward: a run started for Level 2 starts in Vela with what a player
## promoted out of it has, research open on its first stage and the hints met there seen, then
## jumps to Lyra, whose first save keeps the run as Level 2 began. Every feature hint names
## the level it is met in.

const SCENE := "res://game/solar_system/solar_system.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")


# A jump that failed under the loading screen must not leave the next test paused.
func after_test() -> void:
	get_tree().paused = false
	await assert_func(SceneFlow, "is_busy").wait_until(5000).is_false()
	get_tree().root.set_disable_input(false)


func before() -> void:
	SaveGame.use_test_files("fast_forward")


func after() -> void:
	SaveGame.use_player_files()


func test_every_feature_hint_names_the_level_it_is_met_in() -> void:
	for hint: StringName in FeatureHints.HINTS:
		(
			assert_bool(FastForward.HINT_LEVELS.has(hint))
			. override_failure_message(
				"FastForward.HINT_LEVELS has no level for the %s hint" % hint
			)
			. is_true()
		)


func test_fast_forwarding_to_level_2_promotes_out_of_vela_and_jumps_to_lyra() -> void:
	SaveGame.delete()
	SaveGame.start_run({Campaign.FAST_FORWARD_KEY: 2})
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var ledger := (runner.scene() as SolarSystem).get_ledger()
	var arrival: Dictionary = FastForward.ARRIVALS[2]
	assert_int(ledger.credits).is_between(arrival.credits.x, arrival.credits.y)
	assert_int(ledger.get_research()).is_between(arrival.points.x, arrival.points.y)
	assert_int(ledger.get_rating_count()).is_between(arrival.rides.x, arrival.rides.y)
	assert_float(ledger.get_average_rating()).is_between(3.0, 5.0)
	assert_float(ledger.get_recent_rating()).is_between(3.0, 5.0)
	var research := (runner.find_child("ResearchLab") as ResearchLab).get_research()
	assert_bool(research.is_opened()).is_true()
	assert_int(research.get_open_stages()).is_equal(1)
	assert_bool(research.has_researched_any()).is_true()
	assert_bool(SaveGame.is_tutorial_done()).is_true()
	assert_bool(SaveGame.has_seen_hint(&"goals")).is_true()
	assert_bool(SaveGame.has_seen_hint(ResearchGuide.SEEN)).is_true()
	assert_bool(SaveGame.has_seen_hint(&"business")).is_false()

	# The jump's loading screen waits for Start, as answering The Boss's call does.
	var start := SceneFlow.find_child("StartButton", true, false) as Button
	var shown := await PauseProofWait.for_condition(
		func() -> bool: return start.is_visible_in_tree() and get_tree().paused, 20000
	)
	assert_bool(shown).override_failure_message("Level 2's loading screen never showed").is_true()
	if is_failure():
		return
	var jump := runner.find_child("SystemJump") as SystemJump
	monitor_signals(jump)
	start.pressed.emit()
	var lyra := runner.find_child("Lyra") as StarSystem
	await assert_signal(jump).wait_until(10000).is_emitted("finished", [lyra])
	assert_object((runner.find_child("StarMap") as StarMap).get_current()).is_same(lyra)


func test_fast_forwarding_to_level_3_starts_in_lyra_on_two_stages() -> void:
	SaveGame.delete()
	SaveGame.start_run({Campaign.FAST_FORWARD_KEY: 3})
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var star_map := runner.find_child("StarMap") as StarMap
	assert_object(star_map.get_current()).is_same(runner.find_child("Lyra"))
	var research := (runner.find_child("ResearchLab") as ResearchLab).get_research()
	assert_int(research.get_open_stages()).is_equal(2)
	var ledger := (runner.scene() as SolarSystem).get_ledger()
	var arrival: Dictionary = FastForward.ARRIVALS[3]
	assert_int(ledger.get_rating_count()).is_between(arrival.rides.x, arrival.rides.y)
	assert_bool(SaveGame.has_seen_hint(&"business")).is_true()
	assert_bool(SaveGame.has_seen_hint(&"vip")).is_false()
