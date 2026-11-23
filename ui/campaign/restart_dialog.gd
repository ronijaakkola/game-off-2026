class_name RestartDialog
extends Control
## Asks before a level starts over: restarting the level in progress, or playing a finished
## one again while another is in progress. It says what is lost and, past Level 1, what
## carries over. Cancel or Esc closes it; Restart level (or Play again) closes it and
## [signal confirmed]. It covers the screen with a dark scrim and takes the focus while open.

## The player confirmed.
signal confirmed

var _opener: Control


## Asks whether to start [param level] over, where the run is now in [param in_progress]:
## the same level is a restart, another a replay that ends that run.
func ask(level: Level, in_progress: Level) -> void:
	var number := Campaign.number(level)
	var replay := in_progress != null and in_progress != level
	if replay:
		(%Title as Label).text = "Play Level %d again?" % number
		(%Lost as Label).text = "Your run in Level %d ends." % Campaign.number(in_progress)
		(%ConfirmButton as Button).text = "Play again"
	else:
		(%Title as Label).text = "Restart Level %d?" % number
		(%Lost as Label).text = "Your progress in this run of Level %d is lost." % number
		(%ConfirmButton as Button).text = "Restart level"
	(%KeptRow as Control).visible = number > 1
	var earlier := "Level 1"
	if number == 3:
		earlier = "Levels 1 and 2"
	elif number > 3:
		earlier = "Levels 1 to %d" % (number - 1)
	(%Kept as Label).text = "Everything you earned in %s carries over." % earlier
	_opener = get_viewport().gui_get_focus_owner()
	show()
	(%CancelButton as Button).grab_focus()


func _close() -> void:
	hide()
	if is_instance_valid(_opener):
		_opener.grab_focus()


func _on_cancel_button_pressed() -> void:
	_close()


func _on_confirm_button_pressed() -> void:
	_close()
	confirmed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
