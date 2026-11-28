class_name PauseMenu
extends CanvasLayer
## Pauses the game scene that instances it. The pause action (Esc) opens and closes it, and
## on the web, leaving browser fullscreen opens it.
## It starts hidden, so a game scene only instances it. It processes always, so it still
## takes input while the game is paused, and its layer draws it over the game's own UI.
## Whatever else pauses the game, such as the research screen, holds the pause the same
## way ([method hold], [method release]), so the game runs again only once nothing holds it.
## It shows over the game as it stood, blurred and dimmed, its HUD too: its layer draws
## over theirs, so the backdrop's glass reads them from the screen.
## It fades in; it closes at once, as the game picks up again at once. Settings and Controls
## open over it as from the main menu, its rows staggering out and back.
## While [member offers_skip_tutorial], as through the tutorial, a Skip tutorial button
## sits at the bottom, a little apart from the rest: it closes the menu and
## [signal skip_tutorial_pressed].

## The player pressed Skip tutorial.
signal skip_tutorial_pressed

## The nodes holding the game paused.
const HOLDERS := &"pause_holders"
## Seconds to fade in.
const FADE_IN_SECONDS := 0.2

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

## Where the game is, to know which level Restart level starts over. Without it, as in the
## menu's own scene, it is the saved run's level.
@export var star_map: StarMap

## Whether the window shrinking opens the menu. In browser fullscreen, Esc only leaves
## fullscreen and the game never receives it, so leaving fullscreen opens the menu, as that Esc
## would have. On only on the web; a test turns it on to reach it.
var opens_when_window_shrinks := OS.has_feature("web")

## Whether the menu offers to skip the tutorial.
var offers_skip_tutorial := false:
	set(value):
		offers_skip_tutorial = value
		if is_node_ready():
			(%SkipTutorialButton as Control).visible = value
			(%SkipGap as Control).visible = value

var _window_size := Vector2i.ZERO


func _ready() -> void:
	_window_size = get_window().size
	get_window().size_changed.connect(_on_window_size_changed)


## Pauses the game while [param holder] holds it.
static func hold(holder: Node) -> void:
	holder.add_to_group(HOLDERS)
	holder.get_tree().paused = true


## Lets go of [param holder]'s hold, and the game runs again unless another node holds it.
static func release(holder: Node) -> void:
	holder.remove_from_group(HOLDERS)
	holder.get_tree().paused = holder.get_tree().has_group(HOLDERS)


## Whether a node other than [param holder] holds the game paused.
static func is_held_by_another(holder: Node) -> bool:
	for node: Node in holder.get_tree().get_nodes_in_group(HOLDERS):
		if node != holder:
			return true
	return false


# The pause is the menu's, so it goes with the menu: a game scene freed while paused (a
# restart, a test's scene runner) leaves the next one running.
func _exit_tree() -> void:
	if visible:
		release(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


# Leaving fullscreen shows as the window shrinking. itch fullscreens the game's iframe from
# outside, so the window mode never changes, and a fullscreen window can be smaller than the
# screen (a notch, display scaling), so neither tells. Shrinking the browser window pauses too.
# The root window's size is the browser's: Godot sets it from the display server just before
# emitting size_changed.
func _on_window_size_changed() -> void:
	var size := get_window().size
	var shrank := size != _window_size and size.x <= _window_size.x and size.y <= _window_size.y
	_window_size = size
	if opens_when_window_shrinks and shrank and not visible:
		open()


## Shows the menu with Resume focused, and pauses the game.
func open() -> void:
	show()
	var root := %Root as Control
	root.modulate.a = 0.0
	var fade := root.create_tween()
	fade.tween_property(root, ^"modulate:a", 1.0, FADE_IN_SECONDS).set_ease(Tween.EASE_OUT)
	FocusRing.grab(%ResumeButton as Control)
	hold(self)


## Hides the menu, and any screen open over it, and unpauses the game.
func close() -> void:
	%SettingsMenu.hide()
	%ControlsScreen.hide()
	%RestartDialog.hide()
	hide()
	release(self)


func _on_skip_tutorial_button_pressed() -> void:
	close()
	skip_tutorial_pressed.emit()


func _on_resume_button_pressed() -> void:
	close()


func _on_settings_button_pressed() -> void:
	%SettingsMenu.open(%Content, _rows)


func _on_controls_button_pressed() -> void:
	%ControlsScreen.open(%Content, _rows)


# The title and each row of plates shown, top to bottom, which stagger out as a screen
# opens over the menu ([MenuScreen]).
func _rows() -> Array[Control]:
	var rows: Array[Control] = [%TitleMargin]
	for row: Control in %Items.get_children():
		if row.visible:
			rows.append(row)
	return rows


func _on_restart_button_pressed() -> void:
	var level := _level()
	(%RestartDialog as RestartDialog).ask(level, level)


# Starts the level over, through the tutorial again if it is under way.
func _on_restart_dialog_confirmed() -> void:
	Campaign.restart(_level(), offers_skip_tutorial)


# The level the game is in.
func _level() -> Level:
	var level := Campaign.find(String(star_map.get_furthest().name)) if star_map else null
	if level == null:
		level = Campaign.get_in_progress()
	return level if level else Campaign.LEVELS[0]


func _on_main_menu_button_pressed() -> void:
	SceneFlow.go_to(MAIN_MENU_SCENE)
