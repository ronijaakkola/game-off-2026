class_name FlybyZone
extends MeshInstance3D
## The zone round the planet of a fly past or photo stop quest ([FlybyQuest],
## [PhotoStopQuest]) under way: a disc on the orbit plane, 2 units across before it is
## sized, that follows the planet and reaches as far from its surface as the quest's goal
## does, so flying into it is the flyby, and stopping in it the photo stop. For a hop quest
## ([HopQuest]) it is a smaller disc at the hop location, in open space, where the bus has
## to come to rest; one that follows a moon and is open only at times ([WindowHopGoal]) is
## a faint ring with no fill while closed, and its [HopWindowArc] marks where on the moon's
## orbit it is open. It fades in when the quest is taken on and out when it ends. Its ring
## of dashes turns slowly, and holds still under Reduce motion. While the pointer is on the
## quest's row in the goal panel it pulses brighter, so the player sees where the row sends
## them; under Reduce motion it brightens without pulsing.
## It stays visible and only fades, so the scene's first draw compiles its shader.

## Seconds it takes to fade in or out.
const FADE_SECONDS := 0.4
## How fast the ring of dashes turns, in radians a second.
const TURN_SPEED := 0.12

## Pulses a second while the pointer is on the quest's row, and how fast the pulse's
## strength eases in and out, per second.
const PULSE_RATE := 1.1
const FLASH_EASE := 5.0
## How fast a hop location's zone lights up as its window opens, and dims, per second.
const OPEN_EASE := 2.5

## Whose quest under way it shows.
@export var quest_giver: QuestGiver

# The planet it is round, or null for a hop quest's spot in open space, [member _spot].
var _planet: Planet
var _spot := Vector3.ZERO
var _reach := 0.0
var _shown := 0.0
var _open := 1.0
var _turn := 0.0
# How strong the pulse is now, and how long it has run.
var _flash := 0.0
var _time := 0.0


func _process(delta: float) -> void:
	var quest := quest_giver.get_quest() if quest_giver else null
	var goal := quest.goal as FlybyGoal if quest else null
	var hop := quest.goal as HopGoal if quest else null
	var material := material_override as ShaderMaterial
	if goal:
		_planet = goal.planet
		_reach = goal.reach
	elif hop:
		_planet = null
		_spot = hop.get_spot()
		_reach = hop.radius
	(%WindowArc as HopWindowArc).show_window(hop as WindowHopGoal, delta)
	_open = move_toward(_open, 0.0 if hop and not hop.is_open() else 1.0, OPEN_EASE * delta)
	ShaderValues.show(material, &"open", _open)
	var wanted := 1.0 if goal or hop else 0.0
	_shown = move_toward(_shown, wanted, delta / FADE_SECONDS)
	ShaderValues.show(material, &"opacity", _shown)
	if _shown <= 0.0 or _reach <= 0.0:
		return
	if not Settings.reduce_motion:
		_turn = fmod(_turn + TURN_SPEED * delta, TAU)
	ShaderValues.show(material, &"turn", _turn)
	var pointed := quest != null and quest_giver.pointed == quest
	_flash = move_toward(_flash, 1.0 if pointed else 0.0, FLASH_EASE * delta)
	_time = _time + delta if _flash > 0.0 else 0.0
	var pulse := 0.6
	if not Settings.reduce_motion:
		pulse = 0.6 + 0.4 * cos(TAU * PULSE_RATE * _time)
	ShaderValues.show(material, &"flash", _flash * pulse)
	global_position = _planet.get_body_global_position() if _planet else _spot
	scale = Vector3.ONE * ((_planet.get_body_radius() if _planet else 0.0) + _reach)
