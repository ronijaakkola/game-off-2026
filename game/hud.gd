extends MarginContainer
## The game's HUD: how many pieces have been placed, and a Pause button. It counts
## [signal Events.piece_placed], so it doesn't need to know who places them.

## The Pause button was pressed. Browser fullscreen swallows Esc, so there it's the only
## way to pause.
signal pause_pressed

var _placed := 0


func _ready() -> void:
	Events.piece_placed.connect(_on_piece_placed)
	_show_count()


func _on_piece_placed(_position: Vector3) -> void:
	_placed += 1
	_show_count()


func _show_count() -> void:
	%PlacedLabel.text = "Placed: %d" % _placed


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
