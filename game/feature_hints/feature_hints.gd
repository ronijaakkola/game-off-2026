class_name FeatureHints
extends Node
## Feature hints: the first time the player meets a feature during play, the game pauses,
## the music muffles, the screen dims but for the feature ([HintDim]), and a guide card
## rings it, points at it and says what it is, until the player presses Got it.
## Game code [method offer]s a hint when the player meets its feature; it shows only if
## the player has never closed it ([method SaveGame.has_seen_hint]), so each shows once
## across every run until the player deletes their save data.
## A hint offered while another shows waits its turn. One offered during the tutorial,
## which has guide cards of its own, or with its target hidden, isn't shown and isn't kept
## as seen, so the next time the player meets the feature it is offered again.
## Hints show only in a run the main menu started ([method GameSaver.is_saved_run]), so a
## test, a smoke run or F6 never pauses on one or touches what the player has seen; with
## no [member saver], as in a test of the hints themselves, they always do. The debug
## panel's Forget hints shows them all again. Which the player has seen is read from the
## save game once per hint and kept for the scene: deleting the save data is the main menu's.
## The debug panel's Hints card shows any hint at once, seen or not, tutorial or not, and
## doesn't keep it as seen: on its target, as the hint's owner finds it
## ([method set_debug_target]), or, when that isn't on screen, on a spot in the middle of
## the screen.
## [constant HINTS] has each hint's title, what it says, and the side of its target it
## sits on.

## Seconds from one hint starting to close to the next one opening: once it has gone, and
## a beat, as the tutorial's cards.
const GAP := Tooltip.CLOSE_SECONDS + 0.25
## The debug panel's group for the buttons that show each hint at once.
const DEBUG_GROUP := "Hints"
## The size of the spot in the middle of the screen a hint shown from the debug panel
## points at when its target isn't on screen, in pixels.
const DEBUG_SPOT := Vector2(64.0, 64.0)
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
	&"requests":
	{
		title = "Heard that sound?",
		text =
		(
			"To keep your passengers happy, you need to serve them during their trip. This "
			+ "one wants something. Press and hold this button to hand it to them!"
		),
		side = GuideCard.Side.RIGHT,
	},
	&"business":
	{
		title = "This means business",
		text =
		(
			"You have attracted your first business passenger! They are more demanding but "
			+ "pay better if you treat them well."
		),
		side = GuideCard.Side.LEFT,
	},
	&"returning":
	{
		title = "Returning passenger",
		text =
		(
			"This passenger gave you 5 stars the last time they were on board. Now they are "
			+ "back, happier than before, and will tip you at the end of the trip."
		),
		side = GuideCard.Side.LEFT,
	},
	&"vip":
	{
		title = "VIP passengers",
		text =
		(
			"They want you to visit multiple planets, and do not stand waiting even when "
			+ "docked to a planet. They always want the next seat empty, so they take 2 seats "
			+ "from your bus."
		),
		side = GuideCard.Side.LEFT,
	},
	&"asteroid_field":
	{
		title = "Asteroid field",
		text =
		(
			"The rocks slow the bus to a crawl, and every knock shakes up your passengers. "
			+ "Fly through a gap, or go around the field."
		),
		side = GuideCard.Side.ABOVE,
	},
	&"warp_drive":
	{
		title = "Warp drives",
		text =
		(
			"This planet has a warp drive. It can be used to quickly travel to other planets "
			+ "with warp drives."
		),
		side = GuideCard.Side.LEFT,
	},
	&"goals":
	{
		title = "Goals",
		text = "Here you can see your goals to reach the promotion.",
		side = GuideCard.Side.LEFT,
	},
	&"quests":
	{
		title = "Quests",
		text = "Your active quests show up here.",
		side = GuideCard.Side.LEFT,
	},
	&"jump":
	{
		title = "Next level",
		text =
		(
			"You can keep working in this system as long as you like. When you are ready, "
			+ "click here to move to the next level."
		),
		side = GuideCard.Side.LEFT,
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
# Whether one hint has gone and the next is about to open: a hint offered meanwhile waits.
var _between := false
# The hints the player has closed, as read once from the save game.
var _seen: Dictionary[StringName, bool] = {}
# The dim over the rest of the screen, beside the card, made when the first hint shows.
var _dim: HintDim
# What finds each hint's target for the debug panel, by hint, and the hints it is showing
# or has waiting, which aren't kept as seen.
var _debug_targets: Dictionary[StringName, Callable] = {}
var _forced: Dictionary[StringName, bool] = {}
# The spot in the middle of the screen, made the first time the debug panel needs it.
var _debug_spot: Control


func _ready() -> void:
	guide.kind = GuideCard.Kind.FEATURE_HINT
	guide.ring = true
	guide.acknowledged.connect(_on_acknowledged)
	DebugPanel.add_button("Forget hints", _debug_forget_hints, self)
	for hint: StringName in HINTS:
		DebugPanel.add_button(HINTS[hint].title, _debug_show.bind(hint), self, DEBUG_GROUP)


# The pause and the muffled music are the hints', so they go with the scene.
func _exit_tree() -> void:
	_let_go()


## Shows the hint [param hint] on [param target], pausing the game until the player
## presses Got it, if the player has never closed it. Nothing happens if it is showing or
## waiting already. Returns whether it shows or waits its turn, so an owner that offers it
## every frame can stop; one that wasn't taken may be offered again.
func offer(hint: StringName, target: Control) -> bool:
	assert(HINTS.has(hint), "No feature hint named %s" % hint)
	if _is_taken(hint):
		return true
	if (saver and not saver.is_saved_run()) or (tutorial and tutorial.is_running()):
		return false
	if _has_seen(hint) or not _is_on_screen(target):
		return false
	_take(hint, target)
	return true


## Tells the debug panel's button for [param hint] where the hint's target is:
## [param finder] takes nothing and returns the [Control] the hint would point at now, or
## null when there is none.
func set_debug_target(hint: StringName, finder: Callable) -> void:
	assert(HINTS.has(hint), "No feature hint named %s" % hint)
	_debug_targets[hint] = finder


# Whether the hint [param hint] is showing or waiting its turn.
func _is_taken(hint: StringName) -> bool:
	return (
		hint == _showing or _waiting.any(func(entry: Dictionary) -> bool: return entry.hint == hint)
	)


func _is_on_screen(target: Control) -> bool:
	return is_instance_valid(target) and target.is_visible_in_tree()


# Shows the hint [param hint] on [param target], or has it wait its turn.
func _take(hint: StringName, target: Control) -> void:
	if not _showing.is_empty() or _between:
		_waiting.append({hint = hint, target = target})
	else:
		_show(hint, target)


# Whether the player has closed the hint [param hint].
func _has_seen(hint: StringName) -> bool:
	if not _seen.has(hint):
		_seen[hint] = SaveGame.has_seen_hint(hint)
	return _seen[hint]


## Whether the player has been taught the feature of the hint [param hint]: they have
## closed it, or this run shows no hints, as one the main menu didn't start, so what waits
## on the hint doesn't wait forever.
func has_taught(hint: StringName) -> bool:
	assert(HINTS.has(hint), "No feature hint named %s" % hint)
	if saver and not saver.is_saved_run():
		return true
	return _has_seen(hint)


## Whether a hint is showing.
func is_showing() -> bool:
	return not _showing.is_empty()


func _show(hint: StringName, target: Control) -> void:
	if not _is_on_screen(target):
		_forced.erase(hint)
		_show_next()
		return
	var card: Dictionary = HINTS[hint]
	_showing = hint
	guide.target = target
	guide.title = card.title
	guide.text = card.text
	guide.side = card.side
	if not is_instance_valid(_dim):
		_dim = HintDim.new()
		guide.add_sibling(_dim)
	_dim.target = target
	if not _held:
		_held = true
		PauseMenu.hold(self)
		Audio.muffle_music(true)
		_dim.fade_in()
	guide.open()


# Kept as seen only once closed, so a run left with a hint showing shows it again.
func _on_acknowledged() -> void:
	if not _forced.erase(_showing):
		SaveGame.mark_hint_seen(_showing)
		_seen[_showing] = true
	_showing = &""
	guide.close()
	if _waiting.is_empty():
		_let_go()
		return
	# Still paused: the next one opens once this one has gone.
	_between = true
	await get_tree().create_timer(GAP).timeout
	_between = false
	_show_next()


func _show_next() -> void:
	if _waiting.is_empty():
		_let_go()
		return
	var next: Dictionary = _waiting.pop_front()
	_show(next.hint, next.target)


# The game runs again, unless something else holds it, the music clears and the dim goes.
func _let_go() -> void:
	if not _held:
		return
	_held = false
	PauseMenu.release(self)
	Audio.muffle_music(false)
	if is_instance_valid(_dim):
		_dim.fade_out()


# The debug panel's Hints buttons, one per hint by its title: the hint at once, on its
# target or on the spot in the middle of the screen.
func _debug_show(hint: StringName) -> void:
	if _is_taken(hint):
		return
	var target: Control = null
	if _debug_targets.has(hint):
		target = _debug_targets[hint].call()
	if not _is_on_screen(target):
		target = _get_debug_spot()
	_forced[hint] = true
	_take(hint, target)


func _get_debug_spot() -> Control:
	if not is_instance_valid(_debug_spot):
		_debug_spot = Control.new()
		_debug_spot.name = "DebugHintSpot"
		_debug_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide.add_sibling(_debug_spot)
		_debug_spot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_debug_spot.offset_left = -DEBUG_SPOT.x / 2.0
		_debug_spot.offset_top = -DEBUG_SPOT.y / 2.0
		_debug_spot.offset_right = DEBUG_SPOT.x / 2.0
		_debug_spot.offset_bottom = DEBUG_SPOT.y / 2.0
	return _debug_spot


# The debug panel's Forget hints: every hint shows again the next time it is offered.
func _debug_forget_hints() -> void:
	SaveGame.forget_hints()
	_seen.clear()
