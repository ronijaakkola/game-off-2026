extends CanvasLayer
## Moves between top-level scenes with a fade through black. Entering a level, the black
## holds the level's own loading screen ([LoadingCard]), or for a level with no picture yet,
## "Loading…" over a bar that fills as the level loads; anywhere else it stays plain black.
## Input is blocked while fading. It processes always, so a paused scene can leave too, and
## the next scene starts unpaused. A level, once loaded, waits
## paused under its loading screen until the player presses Start (a click, Enter or Space),
## so they can read the tip first; meanwhile no other key reaches the game. The jump into the
## next level within the game scene shows the same screen, with nothing to load
## ([method show_loading_screen]). Either way the level's loading screen fills its bar for at
## least [member min_loading_seconds] before Start shows, however little there was to load.
##
## The bar counts the two kinds of work the wait is made of, each in steps it can draw
## between, because the web build has one thread: a threaded load blocks it and can't
## report progress.
## [br]- Loading the scene's files. The card loads them itself, everything a file uses
## before the file, and redraws the bar every [member step_msec]. Each [code]load()[/code]
## then only builds its own file, because what it uses is already cached.
## [br]- Drawing the scene for the first time, which compiles a shader for each material.
## The card shows the scene's 3D objects one new material at a time under it, a frame each,
## and with the first of those frames the materials of its UI, hidden panels' too
## ([CanvasWarmUp]).

const FADE := 0.25
const THEME := preload("res://ui/theme.tres")
const LOADING_CARD := preload("res://core/scene_flow/loading_card.tscn")
## The bar's share for loading files; drawing the scene the first time fills the rest. Set
## from the solar system's load in Chrome (web export, Windows, measured 2026-11-08): files
## 0.24 s, the first draw 2.7 s.
const LOAD_SHARE := 0.1

## How long one load step may take before the bar is drawn again, in milliseconds. Each
## redraw costs a frame. 0 draws after every file.
var step_msec := 33
## The least time a level's loading screen fills its bar for before the Start button shows,
## in seconds, counted from when the screen has faded in. A level whose files are cached,
## and a jump, which loads nothing, would otherwise show Start at once, and the screen would
## read as a menu, not as arriving somewhere.
var min_loading_seconds := 2.0

## The black card with the bar on it. Its alpha is the fade.
var _curtain: Control
## "Loading…" over the bar, shown only on its own: the curtain's fade reaches each of its
## children apart, so it would show through the level's loading screen as that fades.
var _plain: Control
var _bar: ProgressBar
## Draws a new scene's 2D materials for the first time, under the black.
var _specks: CanvasWarmUp
## The level's loading screen, over the black card while a level loads.
var _level_card: LoadingCard
var _busy := false
var _fade: Tween
# Whether the loaded level waits for Start.
var _waiting := false
# How long the level's loading screen has shown for since it faded in, in seconds.
var _shown_seconds := 0.0


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
	# Under the black, so its specks draw unseen.
	_specks = CanvasWarmUp.new()
	_specks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.add_child(_specks)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.add_child(black)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.add_child(center)
	_plain = center
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
	_level_card = LOADING_CARD.instantiate()
	_level_card.hide()
	_curtain.add_child(_level_card)


## Fades to black, loads the scene at [param path], changes to it and fades back in.
## Entering a [param level], the black holds the level's loading screen, or "Loading…" over
## a filling bar while the level has no picture yet. Callers hold [param path] as a
## [code]const[/code]; preloading the scene would make menu and game preload each other. A
## call made during a transition is ignored.
func go_to(path: String, level: Level = null) -> void:
	if _busy:
		return
	_busy = true
	get_tree().root.set_disable_input(true)
	var has_picture := level != null and not level.picture.is_empty()
	if has_picture:
		_level_card.show_level(level)
		_level_card.show()
	_plain.visible = level != null and not has_picture
	_set_progress(0.0)
	_curtain.show()
	await _fade_to(1.0)
	# The fade reached the card in this step, so the screen still shows the frame before.
	# Draw the whole card first: each load step blocks, and the web build freezes on the
	# last frame drawn.
	await get_tree().process_frame
	_shown_seconds = 0.0
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
		if _level_card.visible:
			await _wait_for_start()
	else:
		push_error("SceneFlow can't change to %s: %s" % [path, error_string(error)])
	await _lift()


## Shows [param level]'s loading screen over a scene that is already black, as the bus jumps
## into the level within the game scene: nothing loads, so its bar fills over
## [member min_loading_seconds], then it holds the game paused until the player presses Start,
## and fades back to the scene's black. It returns then. A level with no picture yet shows
## nothing, and neither does a call made during a transition.
func show_loading_screen(level: Level) -> void:
	if _busy or level == null or level.picture.is_empty():
		return
	_busy = true
	get_tree().root.set_disable_input(true)
	_level_card.show_level(level)
	_level_card.show()
	_plain.hide()
	_set_progress(0.0)
	_curtain.show()
	await _fade_to(1.0)
	_shown_seconds = 0.0
	await _wait_for_start()
	await _lift()


# Fades the curtain away and takes input again: the transition is over.
func _lift() -> void:
	await _fade_to(0.0)
	_curtain.hide()
	_level_card.hide()
	_level_card.clear()
	get_tree().root.set_disable_input(false)
	_busy = false


## Holds the loaded level paused under its loading screen until the player presses Start,
## which shows once the bar has filled. The card takes the clicks meant for the game under it.
func _wait_for_start() -> void:
	get_tree().paused = true
	while _time_share() < 1.0:
		_set_progress(1.0)
		await get_tree().process_frame
	_set_progress(1.0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_waiting = true
	get_tree().root.set_disable_input(false)
	await _level_card.wait_for_start()
	get_tree().root.set_disable_input(true)
	_waiting = false
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false


# While the level waits for Start, Enter and Space reach the focused Start button, and no
# other key reaches the game: Esc would open its pause menu under the card.
func _input(event: InputEvent) -> void:
	if not _waiting or event.is_action(&"ui_accept"):
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


# A load step that blocks makes one long frame, whose delta counts whole. The game scene
# runs at its own time scale, which the wait is not part of.
func _process(delta: float) -> void:
	_shown_seconds += delta / maxf(Engine.time_scale, 0.001)


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
			_set_progress(LOAD_SHARE * (i + 1) / parts)
			await get_tree().process_frame
			step_start = Time.get_ticks_msec()
	_set_progress(LOAD_SHARE)


## Draws [param scene] for the first time under the card, its 3D objects one new material at
## a time, and fills the rest of the bar as they show. The first draw of a material compiles
## its shader, which is most of the wait on the web: drawn all at once, the bar would stand
## still at its end. Objects whose materials are already drawn show with the next step.
## An object the scene starts hidden or off screen draws for its step too, so its shader
## doesn't compile, and the game hitch, when it first shows. Both are set in the
## RenderingServer only, so [member Node3D.visible] stays as the scene set it.
func _warm_up(scene: Node) -> void:
	var steps := _warm_up_steps(scene)
	for step: Array in steps:
		for geometry: GeometryInstance3D in step:
			if geometry.get_instance().is_valid():
				RenderingServer.instance_set_visible(geometry.get_instance(), false)
	# The bar is set before each frame, so the frame that does a step shows it done.
	var parts := steps.size() + 1
	# The first frame draws the sky, the environment and the UI, with no 3D objects, and
	# the materials of the UI that starts hidden.
	_specks.fill(scene)
	_set_progress(lerpf(LOAD_SHARE, 1.0, 1.0 / parts))
	await get_tree().process_frame
	_specks.clear()
	for i: int in steps.size():
		_draw_step(steps[i], true)
		_set_progress(lerpf(LOAD_SHARE, 1.0, float(i + 2) / parts))
		await get_tree().process_frame
		_draw_step(steps[i], false)


## Draws the objects of one warm-up [param step] wherever they are, hidden and off screen
## ones too, while [param forced]; otherwise gives each back the visibility its node has.
func _draw_step(step: Array, forced: bool) -> void:
	# Variant, not typed: the scene may have freed an object since, and a typed loop
	# variable fails on a freed one.
	for item: Variant in step:
		if not is_instance_valid(item):
			continue
		var geometry := item as GeometryInstance3D
		var instance := geometry.get_instance()
		if not instance.is_valid():
			continue
		RenderingServer.instance_set_ignore_culling(instance, forced)
		RenderingServer.instance_set_visible(instance, forced or geometry.is_visible_in_tree())


## [param scene]'s 3D objects in the steps to draw them in: each step starts with an object
## that has a material no earlier step has. A hidden object is in a step only when it
## starts one.
func _warm_up_steps(scene: Node) -> Array[Array]:
	var steps: Array[Array] = []
	var drawn := {}
	for node: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var new_material := false
		for key: Variant in _material_keys(geometry):
			if not drawn.has(key):
				drawn[key] = true
				new_material = true
		if new_material or steps.is_empty():
			steps.append([geometry])
		elif geometry.is_visible_in_tree():
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


## Fills the bar, and moves the level card's bus marker, to [param progress], 0 to 1. A
## level's loading screen never shows more than its share of [member min_loading_seconds].
func _set_progress(progress: float) -> void:
	if _level_card.visible:
		progress = minf(progress, _time_share())
	_bar.value = progress
	_level_card.set_progress(progress)


## How much of [member min_loading_seconds] the level's loading screen has shown for, 0 to 1.
func _time_share() -> float:
	if min_loading_seconds <= 0.0:
		return 1.0
	return minf(_shown_seconds / min_loading_seconds, 1.0)


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
