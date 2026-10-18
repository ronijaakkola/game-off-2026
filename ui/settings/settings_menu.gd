extends PanelContainer
## The settings panel: volume sliders and Reduce motion, bound to [code]Settings[/code].
## The main menu and the pause menu each instance it hidden and call [method open].
## Back or Esc hides it again.

const DEMO_SFX := preload("res://ui/audio/ui_click.ogg")

@onready var _volumes: Dictionary[HSlider, StringName] = {
	%MasterSlider: &"master_volume",
	%MusicSlider: &"music_volume",
	%SfxSlider: &"sfx_volume",
}


func _ready() -> void:
	for slider: HSlider in _volumes:
		# Every step of a drag is heard at once. Settings saves once the steps stop.
		slider.value_changed.connect(_on_volume_value_changed.bind(slider))
	_read_settings()


## Shows the panel with the current settings, and the first slider focused.
func open() -> void:
	_read_settings()
	show()
	%MasterSlider.grab_focus()


func _read_settings() -> void:
	for slider: HSlider in _volumes:
		slider.set_value_no_signal(Settings.get(_volumes[slider]))
	%ReduceMotionButton.set_pressed_no_signal(Settings.reduce_motion)


func _on_volume_value_changed(value: float, slider: HSlider) -> void:
	Settings.set(_volumes[slider], value)


func _on_sfx_slider_drag_ended(_value_changed: bool) -> void:
	Audio.play_sfx(DEMO_SFX)


func _on_reduce_motion_button_toggled(toggled_on: bool) -> void:
	Settings.reduce_motion = toggled_on


func _on_back_button_pressed() -> void:
	hide()


# Esc goes back, like the Back button, and stops there: the pause menu under the panel
# also closes on Esc, which would resume the game.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
