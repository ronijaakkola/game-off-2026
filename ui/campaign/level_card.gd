class_name LevelCard
extends Button
## A level's card in the campaign screen: its slice of the level's picture, its number and
## name, and how far the player has got with it, a Completed! stamp, an In progress badge
## or, locked, a lock and what opens it. Level 1's card can offer the Play tutorial checkbox.
## Picked, its border is the light one and its picture zooms in a little, easing out (at
## once under Reduce motion). A locked card can't be pressed.

enum State { OPEN = 0, IN_PROGRESS = 1, DONE = 2, LOCKED = 3 }

const SHADER := preload("res://ui/campaign/level_card.gdshader")
## How far the picked card's picture zooms in, and the seconds it takes.
const PICKED_ZOOM := 1.05
const ZOOM_SECONDS := 0.45

## The level shown. Set [method show_level] to fill the card.
var level: Level
var state := State.OPEN
## Whether the card is the picked one.
var picked := false:
	set(value):
		picked = value
		(%PickedBorder as Control).visible = value
		_zoom_to(PICKED_ZOOM if value else 1.0)

var _material := ShaderMaterial.new()
var _zoom: Tween


func _ready() -> void:
	_material.shader = SHADER
	_material.set_shader_parameter(&"zoom", 1.0)
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
	(%TutorialChip as Control).hide()


## Whether the Play tutorial box is ticked.
func wants_tutorial() -> bool:
	return (%PlayTutorial as CheckBox).button_pressed


## Shows the Play tutorial box, cleared, if [param offered], or hides it.
func offer_tutorial(offered: bool) -> void:
	(%TutorialChip as Control).visible = offered
	(%PlayTutorial as CheckBox).button_pressed = false


## Lets go of the picture, so it isn't kept in memory while the game plays.
func clear() -> void:
	_material.set_shader_parameter(&"picture", null)


# At once while the card isn't on screen, so the screen opens with it already zoomed.
func _zoom_to(zoom: float) -> void:
	if _zoom:
		_zoom.kill()
	if Settings.reduce_motion or not is_visible_in_tree():
		_material.set_shader_parameter(&"zoom", zoom)
		return
	_zoom = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_zoom.tween_property(_material, ^"shader_parameter/zoom", zoom, ZOOM_SECONDS)


func _on_picture_resized() -> void:
	_material.set_shader_parameter(&"size", (%Picture as Control).size)
