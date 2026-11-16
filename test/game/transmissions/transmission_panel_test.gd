extends GdUnitTestSuite
## A transmission whose two answers mean the same shows them as two primary buttons of one
## width, and either one accepts. Answering from code, as a balance run does, accepts and
## lets the game run again.

const SCENE := "res://game/transmissions/transmission_panel.tscn"
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64 and the canvas_items stretch would scale every click.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func after_test() -> void:
	get_tree().paused = false


func test_two_answers_alike_are_as_wide_and_either_accepts() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as TransmissionPanel
	var call := Transmission.from_boss()
	call.text = "Hello."
	call.decline_text = "Sure boss"
	call.accept_text = "I'm ready"
	call.answers_alike = true
	panel.open(call)
	panel.skip()
	# The buttons take clicks once they start to fade in.
	await runner.simulate_frames(60)

	var decline := runner.find_child("DeclineButton") as Button
	var accept := runner.find_child("AcceptButton") as Button
	assert_float(decline.size.x).is_equal_approx(accept.size.x, 1.0)
	var answers: Array[bool] = []
	panel.answered.connect(func(accepted: bool) -> void: answers.append(accepted))
	runner.set_mouse_position(decline.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var answered := await PauseProofWait.for_signal(panel.answered, 3000)
	assert_bool(answered).override_failure_message("The transmission never closed").is_true()
	if is_failure():
		return
	assert_array(answers).contains_exactly([true])


func test_accept_answers_yes_and_unpauses() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as TransmissionPanel
	var call := Transmission.from_boss()
	call.text = "Hello."
	panel.open(call)
	assert_bool(get_tree().paused).is_true()
	var answers: Array[bool] = []
	panel.answered.connect(func(accepted: bool) -> void: answers.append(accepted))
	panel.accept()
	var answered := await PauseProofWait.for_signal(panel.answered, 3000)
	assert_bool(answered).override_failure_message("The transmission never closed").is_true()
	if is_failure():
		return
	assert_array(answers).contains_exactly([true])
	assert_bool(get_tree().paused).is_false()


# Closed while the caller talks, as a skipped tutorial closes The Boss's call, the caller
# falls quiet: the text stops coming and the voice stops with it.
func test_close_while_talking_stops_the_voice() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene() as TransmissionPanel
	var call := Transmission.from_boss()
	call.text = TutorialCall.FIRST_TEXT
	panel.open(call)
	await runner.simulate_frames(60, 30)
	var message := runner.find_child("Message") as RichTextLabel
	assert_int(message.visible_characters).is_greater(0)
	panel.close()
	var answered := await PauseProofWait.for_signal(panel.answered, 3000)
	assert_bool(answered).override_failure_message("The transmission never closed").is_true()
	if is_failure():
		return
	var shown := message.visible_characters
	await runner.simulate_frames(60, 30)
	assert_int(message.visible_characters).is_equal(shown)
	for player: AudioStreamPlayer in panel.get_voice().find_children(
		"", "AudioStreamPlayer", true, false
	):
		assert_bool(player.playing).is_false()
