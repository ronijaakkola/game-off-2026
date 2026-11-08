extends CanvasLayer
## Moves between top-level scenes with a fade to a black loading card, "Loading…" over a
## bar that fills as the next scene loads. Input is blocked while fading. It processes
## always, so a paused scene can leave too, and the next scene starts unpaused.
##
## The web build has one thread, so a threaded load blocks it and can't report progress.
## Instead the card loads the scene's files itself, everything a file uses before the file,
## and redraws the bar every [member step_msec]. Each [code]load()[/code] then only builds
## its own file, because what it uses is already cached.

const FADE := 0.25
const THEME := preload("res://ui/theme.tres")

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
		_bar.value = 1.0
		await get_tree().scene_changed
		# This step's delta spans the load, and the next one's the new scene's first frame,
		# which compiles its shaders. Either can skip most of the fade, so draw that frame
		# under the card and fade in after it.
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		push_error("SceneFlow can't change to %s: %s" % [path, error_string(error)])
	await _fade_to(0.0)
	_curtain.hide()
	get_tree().root.set_disable_input(false)
	_busy = false


## Loads every file the scene at [param path] uses, deepest first, drawing the bar between
## steps. The scene itself counts as the last part of the bar, loaded by the caller.
func _load_dependencies(path: String) -> void:
	var files: Array[String] = []
	if ResourceLoader.exists(path):
		_collect_dependencies(path, files, {})
	var parts := files.size() + 1
	var step_start := Time.get_ticks_msec()
	for i: int in files.size():
		load(files[i])
		if Time.get_ticks_msec() - step_start >= step_msec:
			_bar.value = float(i + 1) / parts
			await get_tree().process_frame
			step_start = Time.get_ticks_msec()
	_bar.value = float(files.size()) / parts


## Appends to [param files] what [param path] uses and isn't loaded yet, each file after
## everything it uses. [param seen] holds the paths already visited.
func _collect_dependencies(path: String, files: Array[String], seen: Dictionary) -> void:
	for dependency: String in ResourceLoader.get_dependencies(path):
		var file := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
		if seen.has(file) or ResourceLoader.has_cached(file) or not ResourceLoader.exists(file):
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
