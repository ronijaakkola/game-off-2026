class_name FeatureHints
extends Node
## Feature hints: the first time the player meets a feature during play, the game pauses,
## the music muffles, and a guide card points at it and says what it is, until the player
## presses Got it.
## Game code [method offer]s a hint when the player meets its feature; it shows only if
## the player has never closed it ([method SaveGame.has_seen_hint]), so each shows once
## across every run until the player deletes their save data.
## A hint offered while another shows waits its turn. One offered during the tutorial,
## which has guide cards of its own, or with its target hidden, isn't shown and isn't kept
## as seen, so the next time the player meets the feature it is offered again.
## Hints show only in a run the main menu started ([method GameSaver.is_saved_run]), so a
## test, a smoke run or F6 never pauses on one or touches what the player has seen; with
## no [member saver], as in a test of the hints themselves, they always do. The debug
## panel's Forget hints shows them all again.
## [constant HINTS] has each hint's title, what it says, and the side of its target it
## sits on.

## Seconds from one hint starting to close to the next one opening: once it has gone, and
## a beat, as the tutorial's cards.
const GAP := Tooltip.CLOSE_SECONDS + 0.25
const HINTS := {
	&"heat_zone":
	{
		title = "Heat",
		text =
		(
			"Flying near the star heats the bus. Passengers are getting uncomfortable and the "
			+ "bus will soon overheat. Move away from the star to cool it down."
		),
		side = GuideCard.Side.ABOVE,
	},
}

## The card the hints show on: its own, never the tutorial's.
@export var guide: GuideCard
## No hint shows while it runs.
@export var tutorial: Tutorial
## Hints show only in a run it saves.
@export var saver: GameSaver

# The hint showing, or empty for none, and the hints waiting their turn, each with its
# target.
var _showing := &""
var _waiting: Array[Dictionary] = []
# Whether the hints hold the game paused and the music muffled.
var _held := false


func _ready() -> void:
	guide.kind = GuideCard.Kind.FEATURE_HINT
	guide.acknowledged.connect(_on_acknowledged)
	DebugPanel.add_button("Forget hints", _debug_forget_hints, self)


# The pause and the muffled music are the hints', so they go with the scene.
func _exit_tree() -> void:
	_let_go()


## Shows the hint [param hint] on [param target], pausing the game until the player
## presses Got it, if the player has never closed it. Nothing happens if it is showing or
## waiting already.
func offer(hint: StringName, target: Control) -> void:
	assert(HINTS.has(hint), "No feature hint named %s" % hint)
	if hint == _showing or _waiting.any(func(entry: Dictionary) -> bool: return entry.hint == hint):
		return
	if (saver and not saver.is_saved_run()) or (tutorial and tutorial.is_running()):
		return
	if SaveGame.has_seen_hint(hint):
		return
	if not _showing.is_empty():
		_waiting.append({hint = hint, target = target})
		return
	_show(hint, target)


## Whether a hint is showing.
func is_showing() -> bool:
	return not _showing.is_empty()


func _show(hint: StringName, target: Control) -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		_show_next()
		return
	var card: Dictionary = HINTS[hint]
	_showing = hint
	guide.target = target
	guide.title = card.title
	guide.text = card.text
	guide.side = card.side
	if not _held:
		_held = true
		PauseMenu.hold(self)
		Audio.muffle_music(true)
	guide.open()


# Kept as seen only once closed, so a run left with a hint showing shows it again.
func _on_acknowledged() -> void:
	SaveGame.mark_hint_seen(_showing)
	_showing = &""
	guide.close()
	if _waiting.is_empty():
		_let_go()
		return
	# Still paused: the next one opens once this one has gone.
	await get_tree().create_timer(GAP).timeout
	_show_next()


func _show_next() -> void:
	if _waiting.is_empty():
		_let_go()
		return
	var next: Dictionary = _waiting.pop_front()
	_show(next.hint, next.target)


# The game runs again, unless something else holds it, and the music clears.
func _let_go() -> void:
	if not _held:
		return
	_held = false
	PauseMenu.release(self)
	Audio.muffle_music(false)


# The debug panel's Forget hints: every hint shows again the next time it is offered.
func _debug_forget_hints() -> void:
	SaveGame.forget_hints()
