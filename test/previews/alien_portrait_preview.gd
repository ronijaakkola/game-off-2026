extends Node3D
## Each race's head shapes in its colour with each eye style, a row per race and style,
## for a visual check of the alien portraits. The eyes follow the pointer
## while it moves and wander when it stops, and a click startles them all. S puts them all
## to sleep or wakes them, and the arrow keys push them as a bus would: up brakes, down
## speeds up, left and right turn.

const PORTRAIT := preload("res://game/passengers/alien_portrait.tscn")
const EYE_STYLES: Array[AlienEyeStyle] = [
	preload("res://game/passengers/eye_styles/googly.tres"),
	preload("res://game/passengers/eye_styles/bead.tres"),
]
const SPACING := Vector2(0.8, 0.84)
## How hard the arrow keys push, in units per second squared.
const PUSH := 3.0


func _ready() -> void:
	var races := Race.Type.values()
	var rows := races.size() * EYE_STYLES.size()
	for row: int in rows:
		var race := races[row / EYE_STYLES.size()] as Race.Type
		var style := EYE_STYLES[row % EYE_STYLES.size()]
		var heads := AlienLook.HEADS[race]
		var y := ((rows - 1) / 2.0 - row) * SPACING.y - 0.38
		var label := Label3D.new()
		label.text = style.resource_path.get_file().get_basename().capitalize()
		label.font_size = 40
		label.modulate = Color(0.85, 0.8, 1.0)
		label.position = Vector3(-(heads.size() + 1) / 2.0 * SPACING.x, y + 0.3, 0.0)
		add_child(label)
		for column: int in heads.size():
			var portrait := PORTRAIT.instantiate() as AlienPortrait
			portrait.head_model = heads[column]
			portrait.eye_style = style
			portrait.skin_color = Race.SKIN_COLORS[race]
			var x := (column - (heads.size() - 1) / 2.0) * SPACING.x
			portrait.position = Vector3(x, y, 0.0)
			%Portraits.add_child(portrait)


func _process(_delta: float) -> void:
	# Turning left pushes toward their right, which is the camera's left.
	var push := Vector2(
		float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT)),
		float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN)),
	)
	for node: Node in %Portraits.get_children():
		(node as AlienPortrait).felt_acceleration = push * PUSH


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_S:
		for node: Node in %Portraits.get_children():
			var portrait := node as AlienPortrait
			portrait.asleep = not portrait.asleep
	var motion := event as InputEventMouseMotion
	if motion:
		var camera := %Camera as Camera3D
		for node: Node in %Portraits.get_children():
			var portrait := node as AlienPortrait
			var at := camera.unproject_position(portrait.global_position + Vector3.UP * 0.45)
			var toward := (motion.position - at) / 250.0
			portrait.look_toward(Vector2(toward.x, -toward.y))
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		for node: Node in %Portraits.get_children():
			(node as AlienPortrait).startle()
