extends Node3D
## The Phase Miner prototype: the ship on an 8×8 asteroid field that wraps at its edges.
## Arrow keys or WASD phase the ship through the items in a line, destroying them. Dragging a
## row or column with the mouse slides it, carrying the ship along. [PhaseField] holds the
## rules; this scene draws the field in 3D and animates each move.

## Width of one board cell, in metres. The board is centred on the origin.
const CELL := 1.0
## How high each item's centre sits above the tile tops: rocks, ore and scrap stand on their
## tiles like chess pieces, and crystals hover a little above theirs.
const REST_HEIGHTS := {
	PhaseField.Item.ROCK: 0.34,
	PhaseField.Item.FUEL: 0.26,
	PhaseField.Item.CRYSTAL: 0.58,
	PhaseField.Item.SCRAP: 0.12,
}
## Seconds the ship takes to cross one cell in a phase.
const STEP_TIME := 0.07
## How far the pointer moves on the board, in metres, before a drag picks its axis.
const DRAG_DEADZONE := 0.25
const ROCK_SHAKE := 0.4
const KEY_DIRECTIONS := {
	KEY_UP: Vector2i.UP,
	KEY_W: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN,
	KEY_S: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT,
	KEY_A: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT,
	KEY_D: Vector2i.RIGHT,
}
## Flat, per-face colour for every piece. See the shader for how faces pick their shade.
const FLAT_FACE := preload("res://phase_miner/flat_face.gdshader")
## Piece colours: muted, matte tones, far enough apart in hue to tell at a glance.
const ROCK_COLOR := Color(0.55, 0.56, 0.6)
const FUEL_COLOR := Color(0.94, 0.78, 0.33)
const CRYSTAL_COLOR := Color(0.82, 0.58, 0.88)
const SCRAP_COLOR := Color(0.88, 0.47, 0.44)

var field := PhaseField.new()

var _rng := RandomNumberGenerator.new()
var _item_nodes: Dictionary[Vector2i, Node3D] = {}
var _meshes: Dictionary[PhaseField.Item, Mesh] = {}
var _busy := false
var _ship_move: Tween

# The drag in progress: whether it started, the cell and board point it started on, the axis
# it picked (unset until the pointer leaves the deadzone) and how far it has moved, in cells.
var _dragging := false
var _drag_cell := Vector2i.ZERO
var _drag_start := Vector3.ZERO
var _drag_axis_chosen := false
var _drag_is_row := true
var _drag_offset := 0.0


func _ready() -> void:
	_make_meshes()
	_set_up_environment()
	field.reset(_rng)
	_rebuild_items()
	_place_ship()
	_paint_grid()
	%Hud.show_run(field)
	%Hud.show_message("Phase with the arrow keys or WASD. Drag a row or column to slide it.")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode == KEY_R:
			_new_run()
		elif KEY_DIRECTIONS.has(key.keycode):
			_phase(KEY_DIRECTIONS[key.keycode])
		return
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_start_drag(button.position)
		else:
			_end_drag()
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_move_drag(motion.position)


# --- Phasing ---


func _phase(direction: Vector2i) -> void:
	if _busy or _dragging:
		return
	if field.is_over():
		%Hud.show_message("The run is over. Press R for a new run.")
		return
	var steps := field.phase(direction)
	if steps.is_empty():
		%Hud.show_message("Nothing to phase through that way.")
		return
	_busy = true
	%Ship.rotation.y = _heading_angle(direction)
	for step: Dictionary in steps:
		await _move_ship_to(step.cell)
		if step.item != PhaseField.Item.NONE:
			_destroy_item(step.cell, step.item)
	_busy = false
	_after_move()


func _move_ship_to(cell: Vector2i) -> void:
	var target := _cell_position(cell)
	if _ship_move:
		_ship_move.kill()
	# Wrapping round an edge jumps to the far side instead of sweeping across the board.
	if %Ship.position.distance_to(target) > CELL * 1.5:
		%Ship.position = target
		await get_tree().create_timer(STEP_TIME).timeout
		return
	_ship_move = create_tween()
	_ship_move.tween_property(%Ship, "position", target, STEP_TIME)
	await _ship_move.finished


func _destroy_item(cell: Vector2i, item: PhaseField.Item) -> void:
	var node: Node3D = _item_nodes.get(cell)
	if not node:
		return
	_item_nodes.erase(cell)
	var pop := node.create_tween()
	pop.tween_property(node, "scale", node.scale * 1.4, 0.06)
	pop.tween_property(node, "scale", Vector3.ZERO, 0.12)
	pop.tween_callback(node.queue_free)
	if item == PhaseField.Item.ROCK:
		Feedback.shake(ROCK_SHAKE, Vector2.DOWN)


# --- Sliding ---


func _start_drag(screen_position: Vector2) -> void:
	if _busy or field.is_over():
		return
	var point: Variant = _board_point(screen_position)
	if point == null:
		return
	var cell := _cell_at(point)
	if cell.x < 0 or cell.y < 0 or cell.x >= PhaseField.SIZE or cell.y >= PhaseField.SIZE:
		return
	_dragging = true
	_drag_cell = cell
	_drag_start = point
	_drag_axis_chosen = false
	_drag_offset = 0.0


func _move_drag(screen_position: Vector2) -> void:
	var point: Variant = _board_point(screen_position)
	if point == null:
		return
	var moved: Vector3 = point - _drag_start
	if not _drag_axis_chosen:
		if maxf(absf(moved.x), absf(moved.z)) < DRAG_DEADZONE:
			return
		_drag_axis_chosen = true
		_drag_is_row = absf(moved.x) >= absf(moved.z)
		_paint_grid()
	_drag_offset = (moved.x if _drag_is_row else moved.z) / CELL
	_show_drag()


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if not _drag_axis_chosen:
		return
	var cells := roundi(_drag_offset)
	var line := _drag_cell.y if _drag_is_row else _drag_cell.x
	if cells != 0 and not field.slide(_drag_is_row, line, cells):
		%Hud.show_message("Not enough fuel for that slide.")
	_rebuild_items()
	_place_ship()
	_after_move()


# Shows the dragged line where the pointer has it, items and ship sliding with it.
func _show_drag() -> void:
	for cell: Vector2i in _item_nodes:
		if _in_drag_line(cell):
			_item_nodes[cell].position = _dragged_position(cell)
	if _in_drag_line(field.ship):
		%Ship.position = _dragged_position(field.ship)


func _in_drag_line(cell: Vector2i) -> bool:
	return cell.y == _drag_cell.y if _drag_is_row else cell.x == _drag_cell.x


func _dragged_position(cell: Vector2i) -> Vector3:
	var size := float(PhaseField.SIZE)
	var along := float(cell.x if _drag_is_row else cell.y)
	along = fposmod(along + _drag_offset + 0.5, size) - 0.5
	var at := Vector2(along, cell.y) if _drag_is_row else Vector2(cell.x, along)
	return _grid_position(at)


# --- Run state ---


func _after_move() -> void:
	_paint_grid()
	%Hud.show_run(field)
	if field.hull <= 0:
		%Hud.show_message("Hull breached. Press R for a new run.")
	elif field.is_over():
		%Hud.show_message("Out of fuel. Press R for a new run.")
	elif not field.has_loot():
		field.generate(_rng)
		_rebuild_items()
		_paint_grid()
		%Hud.show_message("Field mined out. A fresh one drifts in.")
	elif field.combo >= 2:
		%Hud.show_message("Combo x%d!" % field.combo)
	else:
		%Hud.show_message("")


func _new_run() -> void:
	if _busy:
		return
	_dragging = false
	field.reset(_rng)
	_rebuild_items()
	_place_ship()
	_paint_grid()
	%Hud.show_run(field)
	%Hud.show_message("New run.")


# --- Board drawing ---


func _rebuild_items() -> void:
	for node: Node3D in _item_nodes.values():
		node.queue_free()
	_item_nodes.clear()
	for row: int in PhaseField.SIZE:
		for column: int in PhaseField.SIZE:
			var cell := Vector2i(column, row)
			var item := field.get_item(cell)
			if item != PhaseField.Item.NONE:
				_item_nodes[cell] = _make_item(cell, item)


# An item is a node on the tile top, turned about its upright axis, with its mesh lifted to
# its rest height. Sliding and popping it then only touch the root.
func _make_item(cell: Vector2i, item: PhaseField.Item) -> Node3D:
	# The same cell always gets the same turn, so items don't change shape after a slide.
	var look := RandomNumberGenerator.new()
	look.seed = hash(cell) + item
	var node := Node3D.new()
	node.position = _cell_position(cell)
	node.rotation.y = look.randf() * TAU
	var body := MeshInstance3D.new()
	body.mesh = _meshes[item]
	body.position.y = REST_HEIGHTS[item]
	match item:
		PhaseField.Item.ROCK:
			body.rotation = Vector3(look.randf_range(-0.4, 0.4), 0.0, look.randf_range(-0.4, 0.4))
			body.scale = Vector3(
				look.randf_range(0.8, 1.1), look.randf_range(0.8, 1.2), look.randf_range(0.8, 1.1)
			)
		PhaseField.Item.SCRAP:
			body.rotation = Vector3(look.randf_range(-0.3, 0.3), 0.0, look.randf_range(-0.3, 0.3))
	node.add_child(body)
	%Items.add_child(node)
	return node


func _place_ship() -> void:
	if _ship_move:
		_ship_move.kill()
	%Ship.position = _cell_position(field.ship)
	%Ship.rotation.y = _heading_angle(field.heading)


# Lights the ship's row and column, the lines it can phase along, or the dragged line.
func _paint_grid() -> void:
	var grid := %Grid.material_override as ShaderMaterial
	grid.set_shader_parameter(&"ship_cell", Vector2(field.ship))
	var dragged := _dragging and _drag_axis_chosen
	var line := _drag_cell.y if _drag_is_row else _drag_cell.x
	grid.set_shader_parameter(
		&"drag_line", Vector3(1.0 if dragged else 0.0, 1.0 if _drag_is_row else 0.0, line)
	)


# The flat colours are picked to show as written, so no tonemapper may bend them.
func _set_up_environment() -> void:
	var environment := (%SpaceSky as WorldEnvironment).environment
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR


func _make_meshes() -> void:
	var rock := SphereMesh.new()
	rock.radius = 0.37
	rock.height = 0.78
	rock.radial_segments = 7
	rock.rings = 4
	rock.material = _material(ROCK_COLOR)
	_meshes[PhaseField.Item.ROCK] = rock

	# A squat canister.
	var fuel := CylinderMesh.new()
	fuel.top_radius = 0.17
	fuel.bottom_radius = 0.17
	fuel.height = 0.52
	fuel.radial_segments = 12
	fuel.material = _material(FUEL_COLOR)
	_meshes[PhaseField.Item.FUEL] = fuel

	# Four segments and one ring make an octahedron: a cut gem.
	var crystal := SphereMesh.new()
	crystal.radius = 0.2
	crystal.height = 0.95
	crystal.radial_segments = 4
	crystal.rings = 1
	crystal.material = _material(CRYSTAL_COLOR)
	_meshes[PhaseField.Item.CRYSTAL] = crystal

	var scrap := BoxMesh.new()
	scrap.size = Vector3(0.42, 0.24, 0.3)
	scrap.material = _material(SCRAP_COLOR)
	_meshes[PhaseField.Item.SCRAP] = scrap


func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLAT_FACE
	material.set_shader_parameter(&"color", color)
	return material


# --- Board geometry ---


# The board point under screen_position, or null when the pointer is off the board's plane.
func _board_point(screen_position: Vector2) -> Variant:
	var camera := %Camera as Camera3D
	var plane := Plane(Vector3.UP, 0.0)
	return plane.intersects_ray(
		camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position)
	)


func _cell_at(point: Vector3) -> Vector2i:
	var half := PhaseField.SIZE * CELL * 0.5
	return Vector2i(floori((point.x + half) / CELL), floori((point.z + half) / CELL))


func _cell_position(cell: Vector2i) -> Vector3:
	return _grid_position(Vector2(cell))


# A cell's centre on the tile tops, at float grid coordinates (column, row).
func _grid_position(at: Vector2) -> Vector3:
	var half := (PhaseField.SIZE - 1) * 0.5
	return Vector3((at.x - half) * CELL, 0.0, (at.y - half) * CELL)


# The ship's model points along −Z, which is up the board (row 0 is the far edge).
func _heading_angle(direction: Vector2i) -> float:
	return atan2(-direction.x, -direction.y)
