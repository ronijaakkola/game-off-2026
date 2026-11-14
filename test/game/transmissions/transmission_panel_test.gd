extends GdUnitTestSuite
## A transmission whose two answers mean the same shows them as two primary buttons of one
## width, and either one accepts.

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
