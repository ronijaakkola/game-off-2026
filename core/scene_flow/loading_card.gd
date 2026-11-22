class_name LoadingCard
extends Control
## A level's loading screen: the level's picture over the whole screen, and along the
## bottom its name, a tip, and the HUD's route line as the loading bar, the bus marker
## riding it from one of the level's planets to another. [SceneFlow] shows it while a level
## loads. Nothing on it moves but the marker.

## Tips any level's loading screen shows, as well as the level's own.
const TIPS: Array[String] = [
	"Hold Frameshift to leave a planet once your passengers are on board.",
	"Flying close to the star heats the bus. Steer away before it overheats.",
	"Refuel while docked before a long trip. An empty tank means paying for a tow.",
	"Esc opens the menu at any time.",
]

# The tip shown last, so the next loading screen shows another.
static var _last_tip := ""


## Shows [param level]: loads its picture, and picks a tip.
func show_level(level: Level) -> void:
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
