class_name LoadingCard
extends Control
## A level's loading screen: the level's picture over the whole screen, and along the
## bottom its name, a tip, and the HUD's route line as the loading bar, the bus marker
## riding it from one of the level's planets to another. [SceneFlow] shows it while a level
## loads. Nothing on it moves but the marker. Once loaded, [method wait_for_start] swaps the
## bar for a Start button under the name, so the player can read the tip and start when ready.

## Tips any level's loading screen shows, as well as the level's own.
const TIPS: Array[String] = [
	"Hold Frameshift to leave a planet once your passengers are on board.",
	"Flying close to the star heats the bus. Steer away before it overheats.",
	"Refuel while docked before a long trip. An empty tank means paying for a tow.",
	"Esc opens the menu at any time.",
]

## Seconds the Start button takes to appear, and the pixels it drops into place meanwhile.
const START_SECONDS := 0.2
const START_DROP := 6.0

# The tip shown last, so the next loading screen shows another.
static var _last_tip := ""

var _level: Level
var _appear: Tween


## Shows [param level]: loads its picture, and picks a tip.
func show_level(level: Level) -> void:
	_level = level
	(%LoadingLabel as Label).text = "Loading…"
	(%Bar as Control).show()
	(%StartButton as Control).hide()
	(%Picture as TextureRect).texture = load(level.picture)
	(%Title as Label).text = level.title
	(%FromPlanet as PlanetIcon).show_color(level.from_planet_color)
	(%ToPlanet as PlanetIcon).show_color(level.to_planet_color)
	(%TipBody as Label).text = _pick_tip(level)
	set_progress(0.0)


## Moves the bus marker to [param progress] of the way along the bar, 0 to 1.
func set_progress(progress: float) -> void:
	(%Loaded as Control).size_flags_stretch_ratio = progress
	(%Left as Control).size_flags_stretch_ratio = 1.0 - progress


## Swaps the bar for the Start button, focused, and "Loading…" for the level's number, and
## returns once the player presses it. The button drops into place as it fades in; under
## Reduce motion it only fades.
func wait_for_start() -> void:
	(%LoadingLabel as Label).text = "Level %d" % Campaign.number(_level)
	(%Bar as Control).hide()
	var start := %StartButton as Button
	start.show()
	FocusRing.grab(start)
	if _appear:
		_appear.kill()
	start.modulate.a = 0.0
	_appear = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_appear.tween_property(start, ^"modulate:a", 1.0, START_SECONDS)
	if not Settings.reduce_motion:
		var rest := start.position.y
		start.position.y = rest - START_DROP
		_appear.tween_property(start, ^"position:y", rest, START_SECONDS)
	await start.pressed


## Lets go of the picture, so it isn't kept in memory while the game plays.
func clear() -> void:
	(%Picture as TextureRect).texture = null


func _pick_tip(level: Level) -> String:
	var tips: Array[String] = TIPS.duplicate()
	tips.append_array(Array(level.tips))
	if tips.size() > 1:
		tips.erase(_last_tip)
	_last_tip = tips.pick_random()
	return _last_tip
