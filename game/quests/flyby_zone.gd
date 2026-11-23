class_name FlybyZone
extends MeshInstance3D
## The zone round the planet of a fly past quest ([FlybyQuest]) under way: a disc on the
## orbit plane, 2 units across before it is sized, that follows the planet and reaches as
## far from its surface as the quest's goal does, so flying into it is the flyby. It fades
## in when the quest is taken on and out when it ends. Its ring of dashes turns slowly,
## and holds still under Reduce motion. While the pointer is on the quest's row in the goal
## panel it pulses brighter, so the player sees where the row sends them; under Reduce
## motion it brightens without pulsing.
## It stays visible and only fades, so the scene's first draw compiles its shader.

## Seconds it takes to fade in or out.
const FADE_SECONDS := 0.4
## How fast the ring of dashes turns, in radians a second.
const TURN_SPEED := 0.12

## Pulses a second while the pointer is on the quest's row, and how fast the pulse's
## strength eases in and out, per second.
const PULSE_RATE := 1.1
const FLASH_EASE := 5.0

## Whose quest under way it shows.
@export var quest_giver: QuestGiver

var _planet: Planet
var _reach := 0.0
var _shown := 0.0
var _turn := 0.0
# How strong the pulse is now, and how long it has run.
var _flash := 0.0
var _time := 0.0


func _process(delta: float) -> void:
	var quest := quest_giver.get_quest() as FlybyQuest if quest_giver else null
	var goal := quest.goal as FlybyGoal if quest else null
	if goal:
		_planet = goal.planet
		_reach = goal.reach
	_shown = move_toward(_shown, 1.0 if goal else 0.0, delta / FADE_SECONDS)
	var material := material_override as ShaderMaterial
	ShaderValues.show(material, &"opacity", _shown)
	if _shown <= 0.0 or not _planet:
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
	global_position = _planet.get_body_global_position()
	scale = Vector3.ONE * (_planet.get_body_radius() + _reach)
