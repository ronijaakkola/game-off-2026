extends GdUnitTestSuite
## How likely a capsule is to hold the castaway, through CapsuleField's public calls, and in
## the game, that the castaway boards only once the player accepts their quest.

const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")
const PREVIEW := "res://test/previews/capsules_preview.tscn"


func test_the_castaway_gets_likelier_with_every_miss_until_certain() -> void:
	var field := auto_free(CapsuleField.new()) as CapsuleField
	field.passenger_chance = 0.1
	field.pity_step = 0.15

	assert_float(field.get_castaway_chance()).is_equal_approx(0.1, 0.001)
	field.castaway_misses = 3
	assert_float(field.get_castaway_chance()).is_equal_approx(0.55, 0.001)
	field.castaway_misses = 6
	assert_float(field.get_castaway_chance()).is_equal(1.0)
	field.castaway_misses = 20
	assert_float(field.get_castaway_chance()).is_equal(1.0)


func test_the_castaway_boards_only_once_their_quest_is_accepted() -> void:
	var runner := scene_runner(PREVIEW)
	var cabin := await _collect_castaway_capsule(runner)
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel

	assert_bool(panel.is_open()).is_true()
	assert_array(cabin.get_passengers()).is_empty()

	panel.accept()
	await PauseProofWait.for_condition(func() -> bool: return not get_tree().paused, 5000)
	await runner.simulate_frames(2)

	assert_int(cabin.get_passengers().size()).is_equal(1)
	assert_bool(Castaway.is_castaway(cabin.get_passengers()[0])).is_true()
	assert_object((runner.find_child("QuestGiver") as QuestGiver).get_quest()).is_not_null()


func test_a_declined_castaway_stays_adrift_and_is_found_for_the_system() -> void:
	var runner := scene_runner(PREVIEW)
	var cabin := await _collect_castaway_capsule(runner)
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel

	panel.close()
	await PauseProofWait.for_condition(func() -> bool: return not get_tree().paused, 5000)
	await runner.simulate_frames(2)

	assert_array(cabin.get_passengers()).is_empty()
	assert_object((runner.find_child("QuestGiver") as QuestGiver).get_quest()).is_null()
	assert_bool((runner.find_child("CapsuleField") as CapsuleField).castaway_found).is_true()


func after_test() -> void:
	get_tree().paused = false


# Puts the castaway's capsule on the bus and waits until their transmission has opened.
func _collect_castaway_capsule(runner: GdUnitSceneRunner) -> Cabin:
	await runner.simulate_frames(3)
	var field := runner.find_child("CapsuleField") as CapsuleField
	var bus := runner.find_child("Bus") as FrameshiftBus
	field.spawn(bus.global_position, Capsule.Contents.PASSENGER)
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	await PauseProofWait.for_condition(panel.is_open, 8000)
	return runner.find_child("Cabin") as Cabin
