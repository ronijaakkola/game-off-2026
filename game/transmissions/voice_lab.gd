extends Node
## The voice lab: a scene for trying the alien voices. Pick a race, a mood, a caller's name
## and some text, press Speak, and the real transmission modal talks it in that race's
## [Voice]. The sliders on the right change the voice's delivery as it plays, and Copy puts
## the values on the clipboard so they can be set in the voice's resource. The stinger
## buttons play a race's call-opening sounds, and Kicked the scream of a passenger kicked
## off the bus (the kick itself is off in the game). Changes live only in this scene: the voice's
## file isn't touched. The debug panel's Voice lab button opens it.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const SAMPLE_NAME := "Reizhis"
const SAMPLE_TEXT := (
	"Hello there, driver! Are you taking the long way round to the Giant? "
	+ "I hope the fuel holds, because I am late. Wait, what is that noise?"
)
## Names for Another caller to pick from, to hear how different callers sound.
const NAMES: Array[String] = [
	"Reizhis",
	"Sufoi",
	"Mibbo",
	"Quenta",
	"Draz",
	"Olmek",
	"Pip",
	"Tarvu",
	"Naloo",
	"Brisk",
	"Zhenn",
	"Umi",
]
const MOODS: Array[Passenger.Mood] = [
	Passenger.Mood.OKAY,
	Passenger.Mood.HAPPY,
	Passenger.Mood.ANNOYED,
	Passenger.Mood.FURIOUS,
]

# The voice being tuned for each race that has one: a copy of the saved one.
var _tuned: Dictionary[Race.Type, Voice] = {}
var _rng := RandomNumberGenerator.new()
# The delivery sliders and their value labels, by the voice property each sets.
var _sliders: Dictionary[StringName, HSlider] = {}
var _readouts: Dictionary[StringName, Label] = {}


func _ready() -> void:
	for race: Race.Type in VoiceSpeaker.VOICES:
		_tune(race)
	for race: Race.Type in Race.Type.values():
		(%RaceOption as OptionButton).add_item(_race_name(race), race)
	for mood: Passenger.Mood in MOODS:
		(%MoodOption as OptionButton).add_item(Passenger.Mood.keys()[mood].capitalize(), mood)
	(%NameEdit as LineEdit).text = SAMPLE_NAME
	(%TextEdit as TextEdit).text = SAMPLE_TEXT
	_show_params()
	_update_caller()


# Starts tuning a fresh copy of [param race]'s saved voice, and has the panel use it.
func _tune(race: Race.Type) -> void:
	_tuned[race] = VoiceSpeaker.VOICES[race].duplicate() as Voice
	(%TransmissionPanel as TransmissionPanel).get_voice().voices[race] = _tuned[race]


func _race() -> Race.Type:
	return (%RaceOption as OptionButton).get_selected_id() as Race.Type


func _race_name(race: Race.Type) -> String:
	return Race.Type.keys()[race].capitalize()


# Rebuilds the sliders for the race picked: one for each tunable number the voice has,
# its range read from the voice's own export.
func _show_params() -> void:
	var rows := %Params as Container
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	_sliders.clear()
	_readouts.clear()
	var race := _race()
	(%ParamsTitle as Label).text = "%s voice" % _race_name(race)
	var voice: Voice = _tuned.get(race)
	(%NoVoice as Control).visible = voice == null
	(%ParamButtons as Control).visible = voice != null
	if not voice:
		return
	for property: Dictionary in voice.get_property_list():
		if property.hint != PROPERTY_HINT_RANGE or not property.usage & PROPERTY_USAGE_EDITOR:
			continue
		rows.add_child(_param_row(voice, property))


func _param_row(voice: Voice, property: Dictionary) -> Control:
	var key := StringName(property.name)
	var range_text := String(property.hint_string).split(",")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var label := Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.text = String(key).capitalize()
	label.custom_minimum_size.x = 120.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = float(range_text[0])
	slider.max_value = float(range_text[1])
	slider.step = float(range_text[2])
	slider.value = float(voice.get(key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_param_changed.bind(key))
	row.add_child(slider)
	var readout := Label.new()
	readout.theme_type_variation = &"SmallLabel"
	readout.custom_minimum_size.x = 36.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = _format(voice.get(key))
	row.add_child(readout)
	_sliders[key] = slider
	_readouts[key] = readout
	return row


func _on_param_changed(value: float, key: StringName) -> void:
	var voice: Voice = _tuned[_race()]
	var is_whole := typeof(voice.get(key)) == TYPE_INT
	voice.set(key, int(value) if is_whole else value)
	_readouts[key].text = _format(voice.get(key))
	_update_caller()


# A number as short as it reads: whole numbers bare, the rest to three places.
func _format(value: Variant) -> String:
	return str(value) if typeof(value) == TYPE_INT else String.num(float(value), 3)


func _on_race_option_item_selected(_index: int) -> void:
	_show_params()
	_update_caller()


func _on_name_edit_text_changed(_text: String) -> void:
	_update_caller()


func _on_another_button_pressed() -> void:
	(%NameEdit as LineEdit).text = NAMES[_rng.randi_range(0, NAMES.size() - 1)]
	_update_caller()


# Shows which of the race's voices the name gives, and its pitch.
func _update_caller() -> void:
	var speaker := (%TransmissionPanel as TransmissionPanel).get_voice()
	speaker.begin(_race(), (%NameEdit as LineEdit).text)
	var label := %CallerPitch as Label
	if not speaker.voice:
		label.text = ""
		return
	label.text = (
		"Voice %d of %d, pitch %s"
		% [
			speaker.get_caller_voice(),
			speaker.voice.voice_count,
			_format(speaker.get_caller_pitch())
		]
	)


func _on_speak_button_pressed() -> void:
	var race := _race()
	var transmission := Transmission.new()
	transmission.caller_name = (%NameEdit as LineEdit).text
	transmission.race = race
	transmission.look = AlienLook.random(_rng, race)
	transmission.mood = (%MoodOption as OptionButton).get_selected_id() as Passenger.Mood
	transmission.text = (%TextEdit as TextEdit).text
	(%TransmissionPanel as TransmissionPanel).open(transmission)


func _on_annoyed_button_pressed() -> void:
	_play_stinger(Voice.Stinger.ANNOYED)


func _on_happy_button_pressed() -> void:
	_play_stinger(Voice.Stinger.HAPPY)


func _on_scared_button_pressed() -> void:
	_play_stinger(Voice.Stinger.SCARED)


func _on_kicked_button_pressed() -> void:
	var speaker := (%TransmissionPanel as TransmissionPanel).get_voice()
	speaker.begin(_race(), (%NameEdit as LineEdit).text)
	speaker.play_kicked()


func _play_stinger(stinger: Voice.Stinger) -> void:
	var speaker := (%TransmissionPanel as TransmissionPanel).get_voice()
	speaker.begin(_race(), (%NameEdit as LineEdit).text)
	speaker.play_stinger(stinger)


# The voice's delivery numbers as text, one to a line, to set in its resource.
func _on_copy_button_pressed() -> void:
	var lines := PackedStringArray([_race_name(_race())])
	for key: StringName in _sliders:
		lines.append("%s = %s" % [key, _readouts[key].text])
	DisplayServer.clipboard_set("\n".join(lines))


# Puts the race's voice back as saved.
func _on_reset_button_pressed() -> void:
	var race := _race()
	if VoiceSpeaker.VOICES.has(race):
		_tune(race)
		_show_params()
		_update_caller()


func _on_back_button_pressed() -> void:
	SceneFlow.go_to(MAIN_MENU_SCENE)
