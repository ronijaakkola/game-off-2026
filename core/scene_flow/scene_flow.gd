extends CanvasLayer
## Moves between top-level scenes with a fade to a black loading card, "Loading…" over a
## bar that fills as the next scene loads. Input is blocked while fading. It processes
## always, so a paused scene can leave too, and the next scene starts unpaused.
##
## The bar counts the two kinds of work the wait is made of, each in steps it can draw
## between, because the web build has one thread: a threaded load blocks it and can't
## report progress.
## [br]- Loading the scene's files. The card loads them itself, everything a file uses
## before the file, and redraws the bar every [member step_msec]. Each [code]load()[/code]
## then only builds its own file, because what it uses is already cached.
## [br]- Drawing the scene for the first time, which compiles a shader for each material.
## The card shows the scene's 3D objects one new material at a time under it, a frame each.

const FADE := 0.25
const THEME := preload("res://ui/theme.tres")
## The bar's share for loading files; drawing the scene the first time fills the rest. Set
## from the solar system's load in Chrome (web export, Windows, measured 2026-11-08): files
## 0.24 s, the first draw 2.7 s.
const LOAD_SHARE := 0.1

## How long one load step may take before the bar is drawn again, in milliseconds. Each
## redraw costs a frame. 0 draws after every file.
var step_msec := 33

## The black card with the bar on it. Its alpha is the fade.
var _curtain: Control
var _bar: ProgressBar
var _busy := false
var _fade: Tween


func _ready() -> void:
	layer = 128
	process_mode = PROCESS_MODE_ALWAYS
	_curtain = Control.new()
	_curtain.theme = THEME
	_curtain.modulate.a = 0.0
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.hide()
	add_child(_curtain)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.add_child(black)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.add_child(center)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	center.add_child(rows)
	var label := Label.new()
	label.text = "Loading…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 6)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.12)))
	_bar.add_theme_stylebox_override("fill", _bar_style(Color(1, 1, 1, 0.85)))
	rows.add_child(_bar)


## Fades to the loading card, loads the scene at [param path] while its bar fills, changes
## to it and fades back in. Callers hold [param path] as a [code]const[/code]; preloading
## the scene would make menu and game preload each other. A call made during a transition
## is ignored.
func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().root.set_disable_input(true)
	_bar.value = 0.0
	_curtain.show()
	await _fade_to(1.0)
	# The fade reached the card in this step, so the screen still shows the frame before.
	# Draw the whole card first: each load step blocks, and the web build freezes on the
	# last frame drawn.
	await get_tree().process_frame
	await _load_dependencies(path)
	get_tree().paused = false
	var error := get_tree().change_scene_to_packed(load(path))
	if error == OK:
		await get_tree().scene_changed
		await _warm_up(get_tree().current_scene)
		# The step after a slow frame has a long delta, which would skip most of the fade,
		# and the last warm-up frame can be slow. Fade in after a frame that isn't.
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		push_error("SceneFlow can't change to %s: %s" % [path, error_string(error)])
	await _fade_to(0.0)
	_curtain.hide()
	get_tree().root.set_disable_input(false)
	_busy = false


## Whether a scene change is under way, until the new scene has faded in.
func is_busy() -> bool:
	return _busy


## Loads every file the scene at [param path] uses, deepest first, filling the bar to
## [constant LOAD_SHARE] in steps. The scene itself is the last part, loaded by the caller.
func _load_dependencies(path: String) -> void:
	var files: Array[String] = []
	if ResourceLoader.exists(path):
		for file: String in _load_order(path):
			if not ResourceLoader.has_cached(file):
				files.append(file)
	var parts := files.size() + 1
	var step_start := Time.get_ticks_msec()
	for i: int in files.size():
		load(files[i])
		if Time.get_ticks_msec() - step_start >= step_msec:
			_bar.value = LOAD_SHARE * (i + 1) / parts
			await get_tree().process_frame
			step_start = Time.get_ticks_msec()
	_bar.value = LOAD_SHARE


## Draws [param scene] for the first time under the card, its 3D objects one new material at
## a time, and fills the rest of the bar as they show. The first draw of a material compiles
## its shader, which is most of the wait on the web: drawn all at once, the bar would stand
## still at its end. Objects whose materials are already drawn show with the next step. They
## are hidden in the RenderingServer only, so their [member Node3D.visible] stays as the
## scene set it.
func _warm_up(scene: Node) -> void:
	var steps := _warm_up_steps(scene)
	for step: Array in steps:
		for geometry: GeometryInstance3D in step:
			if geometry.get_instance().is_valid():
				RenderingServer.instance_set_visible(geometry.get_instance(), false)
	# The bar is set before each frame, so the frame that does a step shows it done.
	var parts := steps.size() + 1
	# The first frame draws the sky, the environment and the UI, with no 3D objects.
	_bar.value = lerpf(LOAD_SHARE, 1.0, 1.0 / parts)
	await get_tree().process_frame
	for i: int in steps.size():
		# Variant, not typed: the scene may have freed an object since, and a typed loop
		# variable fails on a freed one.
		for item: Variant in steps[i]:
			if not is_instance_valid(item):
				continue
			var geometry := item as GeometryInstance3D
			if geometry.get_instance().is_valid():
				RenderingServer.instance_set_visible(
					geometry.get_instance(), geometry.is_visible_in_tree()
				)
		_bar.value = lerpf(LOAD_SHARE, 1.0, float(i + 2) / parts)
		await get_tree().process_frame


## [param scene]'s visible 3D objects in the steps to draw them in: each step starts with an
## object that has a material no earlier step has.
func _warm_up_steps(scene: Node) -> Array[Array]:
	var steps: Array[Array] = []
	var drawn := {}
	for node: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_visible_in_tree():
			continue
		var new_material := false
		for key: Variant in _material_keys(geometry):
			if not drawn.has(key):
				drawn[key] = true
				new_material = true
		if new_material or steps.is_empty():
			steps.append([geometry])
		else:
			steps.back().append(geometry)
	return steps


## What decides which shaders drawing [param geometry] compiles: its kind of node, and each
## material it draws with. Materials on one shader share it.
func _material_keys(geometry: GeometryInstance3D) -> Array[Variant]:
	var keys: Array[Variant] = [geometry.get_class()]
	var materials: Array[Material] = []
	if geometry.material_override:
		materials.append(geometry.material_override)
	var mesh_instance := geometry as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			if material:
				materials.append(material)
	while not materials.is_empty():
		var material: Material = materials.pop_back()
		var shader_material := material as ShaderMaterial
		keys.append(shader_material.shader if shader_material else material)
		if material.next_pass:
			materials.append(material.next_pass)
	return keys


## Every file the scene at [param path] uses, in the order to load them.
func _load_order(path: String) -> Array[String]:
	var files: Array[String] = []
	_collect_dependencies(path, files, {})
	return files


## Appends to [param files] what [param path] uses, each file after everything it uses.
## [param seen] holds the paths already visited.
##
## Scripts are most of the load, and compiling one also compiles every script it names.
## Exported scripts are compiled to binary and report no dependencies, so the walk can't
## see that. A scene's own script (the one sharing its base name) names the types of the
## nodes below it, so it goes last, after the sub-scenes and the other scripts: they compile
## in steps of their own, and it finds them compiled. Loaded first, it compiled the whole
## game in one step.
func _collect_dependencies(path: String, files: Array[String], seen: Dictionary) -> void:
	var own_script := path.get_basename() + ".gd"
	var order: Array[String] = []
	var uses_own_script := false
	for dependency: String in ResourceLoader.get_dependencies(path):
		var file := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
		if file == own_script:
			uses_own_script = true
		else:
			order.append(file)
	if uses_own_script:
		order.append(own_script)
	for file: String in order:
		if seen.has(file) or not ResourceLoader.exists(file):
			continue
		seen[file] = true
		_collect_dependencies(file, files, seen)
		files.append(file)


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	await _fade.tween_property(_curtain, "modulate:a", alpha, FADE).finished


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style
