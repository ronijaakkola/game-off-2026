extends CanvasLayer
## The debug panel: buttons for testing, in the bottom left corner, opened and closed
## with F2. It starts closed and works while the game is paused. A scene adds its own
## buttons with [method add_button], and they go when the scene does, so the panel never
## needs to know which scene is running.
## It ships in every build, release builds included, until [constant ENABLED] is set to
## false before the game is released.

## Whether the panel exists. Set to false before the game is released: F2 then does
## nothing and [method add_button] adds nothing.
const ENABLED := true
## Opens and closes the panel. A physical key, so it is the same on every keyboard layout.
const TOGGLE_KEY := KEY_F2


func _ready() -> void:
	(%Root as Control).hide()
	_update_empty()


func _input(event: InputEvent) -> void:
	if not ENABLED:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		var root := %Root as Control
		root.visible = not root.visible
		get_viewport().set_input_as_handled()


## Whether the panel is open.
func is_open() -> bool:
	return (%Root as Control).visible


## Adds a button labelled [param text] that calls [param action] when pressed. It stays
## while [param scene] is in the tree, so a scene's buttons go when the scene does.
func add_button(text: String, action: Callable, scene: Node) -> void:
	if not ENABLED:
		return
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
	# So keys the game uses, such as Space, never press it.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	button.tree_exited.connect(_update_empty, CONNECT_DEFERRED)
	scene.tree_exiting.connect(button.queue_free)
	(%Buttons as Container).add_child(button)
	_update_empty()


# A line saying so when the running scene adds no buttons.
func _update_empty() -> void:
	(%EmptyLabel as Control).visible = (%Buttons as Container).get_child_count() == 0
