extends Node
## Offers the jump feature hint the first time the player plays on after a promotion they
## stayed for: on the goal panel's jump button, once it has shown for [constant SETTLE_SECONDS]
## of play, so the card opens after The Boss's call has closed and the HUD has settled.

## Seconds of play the jump button shows before the hint: The Boss's transmission has
## faded and the panel has stopped moving, with a beat.
const SETTLE_SECONDS := 1.0

@export var hints: FeatureHints
@export var goal_panel: GoalPanel

# Seconds of play the jump button has shown.
var _shown_seconds := 0.0


func _process(delta: float) -> void:
	var button := goal_panel.get_jump_button()
	if not goal_panel.is_offering_jump() or not button.is_visible_in_tree():
		_shown_seconds = 0.0
		return
	_shown_seconds += delta
	if _shown_seconds < SETTLE_SECONDS:
		return
	if hints.offer(&"jump", button):
		set_process(false)
	else:
		# Not taken now, as during the tutorial: it may be offered again a while later.
		_shown_seconds = 0.0
