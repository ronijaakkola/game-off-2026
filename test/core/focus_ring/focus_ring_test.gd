extends GdUnitTestSuite


func test_grab_shows_the_ring_only_after_a_key() -> void:
	var button := auto_free(Button.new()) as Button
	add_child(button)
	_press(_mouse_click())
	FocusRing.grab(button)
	assert_bool(button.has_focus()).is_true()
	assert_bool(button.has_focus(true)).is_false()

	_press(_key(KEY_TAB))
	FocusRing.grab(button)
	assert_bool(button.has_focus(true)).is_true()

	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	_press(touch)
	FocusRing.grab(button)
	assert_bool(button.has_focus(true)).is_false()


func test_a_key_let_go_keeps_the_last_press() -> void:
	var button := auto_free(Button.new()) as Button
	add_child(button)
	_press(_mouse_click())
	var release := _key(KEY_TAB)
	release.pressed = false
	_press(release)
	FocusRing.grab(button)
	assert_bool(button.has_focus(true)).is_false()


func test_drop_hidden_takes_only_a_hidden_focus() -> void:
	var button := auto_free(Button.new()) as Button
	add_child(button)
	button.grab_focus(true)
	FocusRing.drop_hidden()
	assert_bool(button.has_focus()).is_false()

	button.grab_focus()
	FocusRing.drop_hidden()
	assert_bool(button.has_focus(true)).is_true()


# Straight to the autoload, as the viewport would pass it on, so the event moves no focus.
func _press(event: InputEvent) -> void:
	FocusRing._input(event)


func _mouse_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _key(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key
