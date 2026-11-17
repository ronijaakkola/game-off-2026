extends MarginContainer
## The HUD's pause button in the bottom left corner: a pause icon on the glass that opens the
## pause menu, for a player who can't use Esc, as in browser fullscreen, where the browser
## takes it. It works while the game is paused, as Esc does, so the menu can open over a
## feature hint. Its tooltip doesn't: it closes at once when the game pauses, as every
## tooltip does.

## The player pressed it.
signal pressed


func _ready() -> void:
	(%Button as Button).pressed.connect(pressed.emit)
