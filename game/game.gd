extends Node3D
## The example game scene: a click on the board places a piece on the grid cell under the
## pointer, on the board or on top of another piece. Each placement emits
## [signal Events.piece_placed], plays a sound and shakes the camera.

## The grid a placed piece snaps to: one piece wide and one piece tall. The board is
## 9 cells wide, centred on a cell.
const CELL := Vector3(0.8, 0.4, 0.8)
const RAY_LENGTH := 100.0
const SHAKE := 0.35

## The scene placed on each click.
@export var piece_scene: PackedScene
## Played on each placement.
@export var placed_sound: AudioStream

# Clicks wait here for the next physics frame: the physics space may be locked during
# input, so the docs cast rays from _physics_process().
var _clicks: PackedVector2Array = []


func _ready() -> void:
	_warm_up_shaders()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_clicks.append(click.position)


func _physics_process(_delta: float) -> void:
	for screen_position: Vector2 in _clicks:
		_place_at_screen(screen_position)
	_clicks.clear()


# Casts a ray from the camera through screen_position (viewport coordinates) and places a
# piece where it meets an upward face: the board or a piece's top.
func _place_at_screen(screen_position: Vector2) -> void:
	var camera := %Camera as Camera3D
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to)
	)
	# A side face would put the piece inside the one it hit.
	if hit.is_empty() or (hit.normal as Vector3).y < 0.5:
		return
	_place((hit.position as Vector3).snapped(CELL))


func _place(at: Vector3) -> void:
	var piece := piece_scene.instantiate() as Node3D
	piece.position = at
	%Pieces.add_child(piece)
	Audio.play_sfx(placed_sound, 0.1)
	Feedback.shake(SHAKE, Vector2.DOWN)
	Events.piece_placed.emit(at)


# Shaders compile the first time they're drawn, which stutters on the web. Draw a piece
# for one frame, under the board and while SceneFlow's fade still covers the screen.
func _warm_up_shaders() -> void:
	var piece := piece_scene.instantiate() as Node3D
	piece.position = Vector3.DOWN
	add_child(piece)
	await get_tree().process_frame
	piece.queue_free()
