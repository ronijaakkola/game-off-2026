extends Node3D
## Shows the model given after `--` on the command line, framed from the front right.
## `uv run tools/blender.py export` captures it:
## `godot --path . --scene res://tools/model_preview.tscn -- res://game/models/piece.glb`

## Camera direction from the model: front (+Z), right and above.
const VIEW := Vector3(1.0, 0.8, 1.6)
const MARGIN := 1.3


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	var model: Node3D = (load(args[0]) as PackedScene).instantiate()
	add_child(model)
	_frame(_bounds(model))


func _bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node: Node in root.find_children("*", "VisualInstance3D"):
		var visual := node as VisualInstance3D
		var box := visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _frame(bounds: AABB) -> void:
	var camera := %Camera as Camera3D
	var radius := maxf(bounds.size.length() / 2.0, 0.1)
	var distance := radius * MARGIN / sin(deg_to_rad(camera.fov) / 2.0)
	var center := bounds.get_center()
	camera.position = center + VIEW.normalized() * distance
	camera.look_at(center)
