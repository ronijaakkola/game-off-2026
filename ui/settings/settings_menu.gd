class_name SettingsMenu
extends PanelContainer
## The settings panel: one control per setting, bound to [code]Settings[/code]. Each control
## is named after its setting in PascalCase and marked [code]unique_name_in_owner[/code]:
## [code]%MasterVolume[/code] drives [code]Settings.master_volume[/code]. A float setting
## takes a Range (an HSlider), a bool one a BaseButton (a CheckButton). The name is the only
## link, so a new setting without its control fails as the panel loads.
## A menu instances it hidden and calls [method open]. Back or Esc hides it again. While
## it's open, the menu's own controls under it take no keyboard focus, so Tab stays in the
## panel, and when it hides, focus goes back to the control that opened it.
## Where [member offers_save_deletion] is on and there is a save game, a Delete save button
## sits above Back; it deletes the save once held, as New game starts over.

## The save game was deleted from the panel.
signal save_deleted

const DEMO_SFX := preload("res://ui/audio/ui_click.ogg")

## Whether the panel offers to delete the save game. The main menu's panel does; the pause
## menu's doesn't, since the run under it would save over the deletion at the next planet.
@export var offers_save_deletion := false

var _covered: Control
var _opener: Control
# Each setting's control, by the setting's name.
var _controls: Dictionary[String, Control] = {}


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	for setting: String in Settings.get_names():
		_bind(setting)
	_read_settings()


## Shows the panel with the current settings, and the first slider focused. [param covered]
## holds the opening menu's controls, which take no keyboard focus until the panel hides.
## Does nothing while it's already open, so the focus it hands back stays the opener's.
func open(covered: Control) -> void:
	if _covered != null:
		return
	_covered = covered
	_opener = get_viewport().gui_get_focus_owner()
	_covered.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_read_settings()
	_show_delete_save()
	show()
	%MasterVolume.grab_focus()


# Connects the control named after [param setting], so changing it changes the setting.
func _bind(setting: String) -> void:
	var control := get_node_or_null("%" + setting.to_pascal_case()) as Control
	var value: Variant = Settings.get(setting)
	if value is float and control is Range:
		# Every step of a drag is heard at once. Settings saves once the steps stop.
		(control as Range).value_changed.connect(func(v: float) -> void: Settings.set(setting, v))
	elif value is bool and control is BaseButton:
		(control as BaseButton).toggled.connect(func(on: bool) -> void: Settings.set(setting, on))
	else:
		var kind := "an HSlider" if value is float else "a CheckButton"
		var message := "Settings.%s has no control in the settings panel: add %s with the unique name %s"
		push_error(message % [setting, kind, setting.to_pascal_case()])
		return
	_controls[setting] = control


func _read_settings() -> void:
	for setting: String in _controls:
		var control := _controls[setting]
		if control is Range:
			(control as Range).set_value_no_signal(Settings.get(setting))
		else:
			(control as BaseButton).set_pressed_no_signal(Settings.get(setting))


# Offered only with a save to delete, and enabled again for the next one.
func _show_delete_save() -> void:
	var shown := offers_save_deletion and SaveGame.has_save()
	%SaveDivider.visible = shown
	%DeleteSaveButton.visible = shown
	%DeleteSaveButton.disabled = false
	%DeleteSaveButton.text = "Delete save"


# Stays in place, disabled, so the panel doesn't jump and the player sees it was done.
func _on_delete_save_button_confirmed() -> void:
	SaveGame.delete()
	%DeleteSaveButton.disabled = true
	%DeleteSaveButton.text = "Save deleted"
	%BackButton.grab_focus()
	save_deleted.emit()


func _on_sfx_volume_drag_ended(_value_changed: bool) -> void:
	Audio.play_sfx(DEMO_SFX)


# Hidden by Back, Esc or the menu that opened it, so it hands focus back here.
func _on_visibility_changed() -> void:
	if visible or _covered == null:
		return
	_covered.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_covered = null
	if is_instance_valid(_opener):
		_opener.grab_focus()


func _on_back_button_pressed() -> void:
	hide()


# Esc goes back, like the Back button, and stops there: the pause menu under the panel
# also closes on Esc, which would resume the game.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
