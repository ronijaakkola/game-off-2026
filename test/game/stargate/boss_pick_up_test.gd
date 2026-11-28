extends GdUnitTestSuite
## The Boss's pick-up: in Sol, once the goals hold, The Boss calls once with someone to pick
## up at Earth; answered, they wait there under a marker, nobody the player knows. With the
## bus docked at Earth the meeting plays to its end by itself: everyone on board is kicked
## off, The Boss boards and takes every seat, the stargate is there, the station has its
## row, nobody calls any more, and the player has the bus again.

const SOL := "res://test/previews/sol_preview.tscn"
const MEETING := "res://test/previews/boss_pick_up_preview.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")


## A goal that is always met.
class MetGoal:
	extends Goal

	func is_met() -> bool:
		return true


func after_test() -> void:
	get_tree().paused = false


func test_in_sol_the_boss_calls_once_with_someone_to_pick_up_at_earth() -> void:
	var runner := scene_runner(SOL)
	await runner.simulate_frames(2)
	(runner.find_child("FirstShiftCall") as FirstShiftCall).cancel()
	var goals := runner.find_child("Goals") as GoalTracker
	for goal: Goal in goals.get_goals():
		goals.remove(goal)
	var boss := runner.find_child("GoalsMetCall") as GoalsMetCall
	var pick_up := runner.find_child("BossPickUp") as BossPickUp
	var markers := runner.find_child("PickUpMarkers") as PickUpMarkers
	var earth := runner.find_child("Earth") as Planet

	goals.add(MetGoal.new())
	await runner.simulate_frames(55, 100)

	assert_bool(boss.is_ringing()).is_true()
	assert_bool(pick_up.is_under_way()).is_false()
	var call: Notice = null
	for notice: Notice in (runner.find_child("Notices") as NoticeStack).get_notices():
		if notice.get_text() == NoticeStack.CALL_TEXT:
			call = notice
	assert_object(call).is_not_null()
	call.action_pressed.emit()
	var panel := runner.find_child("TransmissionPanel") as TransmissionPanel
	panel.accept()
	var answered := await PauseProofWait.for_signal(panel.answered, 3000)
	assert_bool(answered).override_failure_message("The transmission never closed").is_true()
	if is_failure():
		return

	assert_bool(pick_up.is_under_way()).is_true()
	assert_bool(markers.has_marker(earth)).is_true()
	# The goals still hold, and The Boss doesn't call again.
	await runner.simulate_frames(70, 100)
	assert_bool(boss.is_ringing()).is_false()


func test_whoever_waits_is_nobody_the_player_knows_until_they_meet() -> void:
	var earth := auto_free(Planet.new()) as Planet

	var boss := BossPassenger.create(earth)

	assert_str(boss.name).is_equal(BossPassenger.UNKNOWN_NAME)
	assert_bool(BossPassenger.is_unknown(boss)).is_true()
	assert_object(boss.look.head).is_not_same(Transmission.BOSS_HEAD)
	assert_object(boss.origin).is_same(earth)
	assert_object(boss.destination).is_null()

	BossPassenger.reveal(boss)

	assert_str(boss.name).is_equal(BossPassenger.NAME)
	assert_bool(BossPassenger.is_unknown(boss)).is_false()
	assert_bool(BossPassenger.is_boss(boss)).is_true()
	assert_object(boss.look.head).is_same(Transmission.BOSS_HEAD)


# The whole meeting, about 45 s of play, so it takes longer than most tests: the preview
# answers the transmission and presses the stargate's row by itself.
func test_docked_at_earth_the_meeting_plays_to_its_end() -> void:
	var runner := scene_runner(MEETING)
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var pick_up := runner.find_child("BossPickUp") as BossPickUp
	var aboard: Array[Passenger] = []
	for i: int in 2:
		aboard.append(waiting.create(runner.find_child("Mars") as Planet))
		cabin.board(aboard[i])
	var kicked: Array[Passenger] = []
	cabin.kicked.connect(func(passenger: Passenger) -> void: kicked.append(passenger))
	var chart := runner.find_child("StarChart") as StarChart
	var charted := [false]
	chart.opened.connect(func() -> void: charted[0] = true)

	var tracker := runner.find_child("Goals") as GoalTracker
	var built := func() -> bool:
		var given := tracker.get_goals().size() == 2 and tracker.get_goals()[1] is FetchGoal
		return pick_up.to_save()["stage"] == BossPickUp.Stage.BUILT and given
	var done := await PauseProofWait.for_condition(built, 90000)
	assert_bool(done).override_failure_message("The meeting never ended").is_true()
	if is_failure():
		return

	assert_array(kicked).contains_exactly_in_any_order(aboard)
	var on_board := cabin.get_passengers()
	assert_int(on_board.size()).is_equal(1)
	assert_str(on_board[0].name).is_equal(BossPassenger.NAME)
	assert_int(cabin.get_free_seats()).is_equal(0)
	assert_bool(Stargate.find(get_tree()).built).is_true()
	assert_bool(charted[0]).override_failure_message("The star chart never showed").is_true()
	# It ends on the star chart, the bus held until the chart closes.
	assert_bool(chart.is_open()).is_true()
	assert_bool(bus.grounded).is_true()
	assert_bool(bus.route_locked).is_true()
	assert_bool((runner.find_child("QuestGiver") as QuestGiver).is_line_free()).is_false()
	var goals := tracker.get_goals()
	var fetched: Array[String] = []
	for goal: Goal in goals:
		fetched.append("%s %s" % [goal.get_text(), (goal as FetchGoal).planet.display_name])
	assert_array(fetched).contains_exactly(
		["Get the briefcase from Brume", "Get the bowtie from Giant"]
	)

	chart.close()
	await await_signal_on(chart, "closed", [], 4000)
	assert_bool(bus.grounded).is_false()
	assert_bool(bus.route_locked).is_false()
	assert_bool((runner.find_child("CameraRig") as CameraRig).locked).is_false()
	await runner.simulate_frames(5)
	var dock := runner.find_child("DockPanel") as DockPanel
	assert_bool(dock.get_stargate_row().is_open()).is_true()


func test_a_save_brings_back_the_quest_or_the_stargate() -> void:
	var runner := scene_runner(SOL)
	await runner.simulate_frames(2)
	(runner.find_child("FirstShiftCall") as FirstShiftCall).cancel()
	var pick_up := runner.find_child("BossPickUp") as BossPickUp
	var markers := runner.find_child("PickUpMarkers") as PickUpMarkers
	var earth := runner.find_child("Earth") as Planet
	var gate := Stargate.find(get_tree())

	pick_up.load_save({"stage": BossPickUp.Stage.CALLED})

	assert_bool(pick_up.is_under_way()).is_true()
	assert_bool(markers.has_marker(earth)).is_true()
	assert_bool(gate.built).is_false()
	assert_dict(pick_up.to_save()).is_equal({"stage": BossPickUp.Stage.CALLED})

	pick_up.load_save({"stage": BossPickUp.Stage.BUILT})
	await runner.simulate_frames(2)

	assert_bool(gate.built).is_true()
	assert_bool((runner.find_child("QuestGiver") as QuestGiver).is_line_free()).is_false()

	# The Boss's goals come back, each as far as it had got.
	var tracker := runner.find_child("Goals") as GoalTracker
	var brume := runner.find_child("Brume") as Planet
	tracker.get_goals()[0].bus_docked(brume)
	var saved := pick_up.to_save()
	pick_up.load_save(saved)
	var goals := tracker.get_goals()
	assert_int(goals.size()).is_equal(2)
	assert_object((goals[0] as FetchGoal).planet).is_same(brume)
	assert_bool(goals[0].is_met()).is_true()
	assert_bool(goals[1].is_met()).is_false()


func test_the_star_chart_leaves_a_stargate_not_yet_built_hidden() -> void:
	var runner := scene_runner(SOL)
	await runner.simulate_frames(2)
	(runner.find_child("FirstShiftCall") as FirstShiftCall).cancel()
	var chart := runner.find_child("StarChart") as StarChart
	var gate := Stargate.find(get_tree())
	assert_bool(gate.visible).is_false()

	chart.open()
	await await_signal_on(chart, "opened", [], 4000)
	assert_bool(gate.visible).is_false()
	chart.close()
	await await_signal_on(chart, "closed", [], 4000)

	assert_bool(gate.visible).is_false()
