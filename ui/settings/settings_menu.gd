class_name SettingsMenu
extends MenuScreen
## The settings screen: one control per setting, bound to [code]Settings[/code]. Each control
## is named after its setting in PascalCase and marked [code]unique_name_in_owner[/code]:
## [code]%MasterVolume[/code] drives [code]Settings.master_volume[/code]. A float setting
## takes a Range (an HSlider), a bool one a BaseButton (a CheckButton). The name is the only
## link, so a new setting without its control fails as the screen loads.
## A menu opens it over itself ([MenuScreen]).
## Where [member offers_campaign_reset] is on, a Campaign progress card holds a Reset
## campaign button, held to confirm, which forgets the run and how far the player has got
## ([method Campaign.reset]), as well as the tutorial and the feature hints seen, so the
## game starts as on a first visit. With nothing to reset it is off, and says so.

## The campaign was reset from the screen.
signal campaign_reset

const DEMO_SFX := preload("res://ui/audio/ui_click.ogg")

## Whether the screen offers to reset the campaign. The main menu's does; the pause menu's
## doesn't, since the run under it would save over the reset at the next planet.
@export var offers_campaign_reset := false

# Each setting's control, by the setting's name.
var _controls: Dictionary[String, Control] = {}


func _ready() -> void:
	super._ready()
	for setting: String in Settings.get_names():
		_bind(setting)
	_read_settings()
	# Show FPS has no description, yet stands as tall as a row with one, label centred, so the
	# toggles sit evenly spaced.
	%ShowFpsRow.custom_minimum_size.y = %EdgeScrollRow.get_combined_minimum_size().y


func _opening() -> void:
	_read_settings()
	_show_campaign_reset()


func _first_control() -> Control:
	return %MasterVolume


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
		var message := "Settings.%s has no control in the settings screen: add %s with the unique name %s"
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


# Off, with a tooltip saying why, while there is nothing to reset.
func _show_campaign_reset() -> void:
	%CampaignCard.visible = offers_campaign_reset
	_set_resettable(Campaign.has_progress())


func _set_resettable(resettable: bool) -> void:
	%ResetCampaignButton.disabled = not resettable
	%ResetCampaignButton.focus_mode = Control.FOCUS_ALL if resettable else Control.FOCUS_NONE
	(%Tooltip as Tooltip).muted = resettable


# Turns off once done, so the screen doesn't jump and the player sees it was done.
func _on_reset_campaign_button_confirmed() -> void:
	Campaign.reset()
	_set_resettable(false)
	FocusRing.grab(%BackButton as Control)
	campaign_reset.emit()


func _on_sfx_volume_drag_ended(_value_changed: bool) -> void:
	Audio.play_sfx(DEMO_SFX)
