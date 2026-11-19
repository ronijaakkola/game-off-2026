class_name MixerVoice
extends VBoxContainer
## One race's voice in the mixer: how loud it is, and buttons that play lines in it as a
## transmission would, with a caller's stinger and pitch and the words typing out.

signal changed

var race := Race.Type.BLUE
var voice: Voice

var _demo: VoiceDemo
# The level in the voice's file, which a reset goes back to.
var _saved := 1.0


## Shows [param race_type]'s [param race_voice], with [param demo] to play its lines.
func setup(race_type: Race.Type, race_voice: Voice, demo: VoiceDemo) -> void:
	race = race_type
	voice = race_voice
	_demo = demo
	var from_file := ResourceLoader.load(voice.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_saved = (from_file as Voice).volume
	(%NameLabel as Label).text = "%s voice" % Race.Type.keys()[race].capitalize()
	var level := %Level as LevelControl
	level.set_level(voice.volume)
	level.changed.connect(_on_level_changed)
	for line: Dictionary in VoiceDemo.LINES:
		var button := _button(String(line["label"]))
		button.pressed.connect(_on_demo_pressed.bind([line]))
	var all := _button("All of these")
	all.theme_type_variation = &"SmallPrimaryButton"
	all.pressed.connect(_on_demo_pressed.bind(VoiceDemo.LINES))
	_show_mark()


func get_level() -> float:
	return voice.volume


## Whether it is not at the level in the voice's file.
func is_edited() -> bool:
	return not is_equal_approx(voice.volume, _saved)


## Back to the level in the voice's file.
func reset() -> void:
	(%Level as LevelControl).set_level(_saved)
	voice.volume = _saved
	_show_mark()
	changed.emit()


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"SmallButton"
	(%Demos as Container).add_child(button)
	return button


func _on_level_changed(level: float) -> void:
	voice.volume = level
	_show_mark()
	changed.emit()


func _show_mark() -> void:
	(%MarkLabel as Label).text = "edited" if is_edited() else ""


func _on_demo_pressed(lines: Array) -> void:
	var entries: Array[Dictionary] = []
	for line: Dictionary in lines:
		entries.append(VoiceDemo.entry(race, voice, line))
	_demo.play(entries)
