class_name LevelCard
extends Button
## A level's card in the campaign screen: its slice of the level's picture, its number and
## name, and how far the player has got with it, a Completed! stamp, an In progress badge
## or, locked, a lock and what opens it. Level 1's card has the Play tutorial checkbox.
## Picked, its border is the light one. A locked card can't be pressed.

enum State { OPEN = 0, IN_PROGRESS = 1, DONE = 2, LOCKED = 3 }

const SHADER := preload("res://ui/campaign/level_card.gdshader")

## The level shown. Set [method show_level] to fill the card.
var level: Level
var state := State.OPEN
## Whether the card is the picked one.
var picked := false:
	set(value):
		picked = value
		(%PickedBorder as Control).visible = value

var _material := ShaderMaterial.new()


func _ready() -> void:
	_material.shader = SHADER
	(%Picture as Control).material = _material
	(%Picture as Control).resized.connect(_on_picture_resized)
	_on_picture_resized()


## Shows [param shown], numbered [param number], as [param card_state] says.
func show_level(shown: Level, number: int, card_state: State) -> void:
	level = shown
	state = card_state
	var has_picture := not level.picture.is_empty()
	_material.set_shader_parameter(&"has_picture", has_picture)
	if has_picture:
		_material.set_shader_parameter(&"picture", load(level.picture))
		var crop := level.card_crop
		var region := Vector4(crop.position.x, crop.position.y, crop.size.x, crop.size.y)
		_material.set_shader_parameter(&"region", region)
	var locked := state == State.LOCKED
	_material.set_shader_parameter(&"locked", locked)
	disabled = locked
	focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	(%Number as Label).text = "Level %d" % number
	(%Title as Label).text = level.title
	(%Title as Label).modulate.a = 0.65 if locked else 1.0
	(%Completed as Control).visible = state == State.DONE
	(%InProgress as Control).visible = state == State.IN_PROGRESS
	(%Locked as Control).visible = locked
	(%LockedReason as Label).text = "Complete Level %d first" % (number - 1)
	(%TutorialChip as Control).visible = number == 1


## Whether the Play tutorial box is ticked.
func wants_tutorial() -> bool:
	return (%PlayTutorial as CheckBox).button_pressed


## Ticks the Play tutorial box, or clears it.
func set_tutorial(on: bool) -> void:
	(%PlayTutorial as CheckBox).button_pressed = on


## Lets go of the picture, so it isn't kept in memory while the game plays.
func clear() -> void:
	_material.set_shader_parameter(&"picture", null)


func _on_picture_resized() -> void:
	_material.set_shader_parameter(&"size", (%Picture as Control).size)
