extends CanvasLayer
## Moves between top-level scenes with a fade to a black loading card ("Loading…"), so
## the player sees the game working while the next scene loads. Input is blocked while
## fading. It processes always, so a paused scene can leave too, and the next scene
## starts unpaused.

const FADE := 0.25
const THEME := preload("res://ui/theme.tres")

## The black card with "Loading…" on it. Its alpha is the fade.
var _curtain: Control
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
	# Still text, not a spinner: on the web, load() blocks the only thread, so anything
	# animated would freeze and look like a hang.
	var label := Label.new()
	label.text = "Loading…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.add_child(label)


## Fades to the loading card, changes to the scene at [param path] and fades back in.
## Callers hold [param path] as a [code]const[/code]; preloading the scene would make menu
## and game preload each other. A call made during a transition is ignored.
func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().root.set_disable_input(true)
	_curtain.show()
	await _fade_to(1.0)
	# The fade reached the card in this step, so the screen still shows the frame before.
	# Draw the whole card first: load() blocks, and the web build freezes on the last frame.
	await get_tree().process_frame
	get_tree().paused = false
	var error := get_tree().change_scene_to_packed(load(path))
	if error == OK:
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


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	await _fade.tween_property(_curtain, "modulate:a", alpha, FADE).finished
