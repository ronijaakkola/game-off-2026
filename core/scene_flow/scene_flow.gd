extends CanvasLayer
## Moves between top-level scenes with a fade to black. Input is blocked while fading.
## It processes always, so a paused scene can leave too, and the next scene starts
## unpaused.

const FADE := 0.25

var _black: ColorRect
var _busy := false


func _ready() -> void:
	layer = 128
	process_mode = PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)


## Fades to black, changes to the scene at [param path] and fades back in. Callers hold
## [param path] as a [code]const[/code]; preloading the scene would make menu and game
## preload each other. A call made during a transition is ignored.
func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().root.set_disable_input(true)
	await _fade_to(1.0)
	get_tree().paused = false
	var error := get_tree().change_scene_to_packed(load(path))
	if error == OK:
		await get_tree().scene_changed
	else:
		push_error("SceneFlow can't change to %s: %s" % [path, error_string(error)])
	await _fade_to(0.0)
	get_tree().root.set_disable_input(false)
	_busy = false


func _fade_to(alpha: float) -> void:
	await create_tween().tween_property(_black, "color:a", alpha, FADE).finished
