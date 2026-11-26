class_name Mixer
extends Control
## The mixer: every sound clip in the game and each alien voice, with a level to set for
## each, a button to hear it, and Copy to put the levels on the clipboard. Music tracks play
## as the music and loop, so a clip can be heard over one. A clip's level is how loud it plays
## as recorded times a number: 1 is as recorded, up to 2. Changes last until the game closes
## and are heard in the game at once; no file is touched. Copy gives the table for
## core/audio/clip_levels.gd and each voice's volume, to set by hand. The debug panel's Mixer
## button opens it.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const ROW_SCENE := preload("res://ui/mixer/mixer_row.tscn")
const VOICE_SCENE := preload("res://ui/mixer/mixer_voice.tscn")
## The lines said in turn by every voice at once, by the lines' labels in [VoiceDemo].
const EVERYONE: Array[String] = ["Plain", "Question", "Exclaim"]

var _rows: Array[MixerRow] = []
var _voices: Array[MixerVoice] = []
var _demo: VoiceDemo


func _ready() -> void:
	_demo = VoiceDemo.new()
	add_child(_demo)
	_show_silenced()
	var sections := %Sections as Container
	var tracks: Array[MixerRow] = []
	var effects: Array[MixerRow] = []
	for path: String in ClipFinder.find():
		var stream := load("res://" + path) as AudioStream
		if not stream:
			continue
		var row := ROW_SCENE.instantiate() as MixerRow
		row.setup(path, stream)
		(tracks if ClipFinder.is_track(stream) else effects).append(row)
	_add_section(sections, "Music", tracks)
	_add_section(sections, "Sound effects", effects)
	_rows.append_array(tracks)
	_rows.append_array(effects)
	_add_voices(sections)


## The names of the volumes set to zero in Settings, which silence what they carry here too.
static func silenced_volumes() -> PackedStringArray:
	var names := PackedStringArray()
	if Settings.master_volume <= 0.0:
		names.append("Master")
	if Settings.music_volume <= 0.0:
		names.append("Music")
	if Settings.sfx_volume <= 0.0:
		names.append("Sound effects")
	return names


## The text Copy puts on the clipboard: [member ClipLevels.LEVELS] as it should read, then
## each voice's volume.
func table_text() -> String:
	var lines := PackedStringArray(["# core/audio/clip_levels.gd, LEVELS"])
	for row: MixerRow in _rows:
		lines.append('\t"%s": %s,' % [row.path, level_text(row.get_level())])
	lines.append("")
	lines.append("# the voices' .tres files")
	for voice: MixerVoice in _voices:
		var file := voice.voice.resource_path.get_file()
		lines.append("%s: volume = %s" % [file, level_text(voice.get_level())])
	return "\n".join(lines)


## A level as it is written in a table: two places at most, and always with a point.
static func level_text(level: float) -> String:
	var text := String.num(level, 2)
	return text if "." in text else text + ".0"


# Warns, under the hint, when a volume in Settings is at zero: it still applies here.
func _show_silenced() -> void:
	var names := silenced_volumes()
	var label := %Silenced as Label
	label.visible = not names.is_empty()
	label.text = (
		(
			"%s set to zero in Settings: raise it there to hear this. "
			+ "The mixer plays through the same volumes as the game."
		)
		% " and ".join(names)
	)


func _add_section(parent: Container, title: String, rows: Array[MixerRow]) -> void:
	var heading := Label.new()
	heading.text = title
	heading.theme_type_variation = &"HeadingLabel"
	parent.add_child(heading)
	for row: MixerRow in rows:
		parent.add_child(row)


func _add_voices(parent: Container) -> void:
	var heading := Label.new()
	heading.text = "Voices"
	heading.theme_type_variation = &"HeadingLabel"
	parent.add_child(heading)
	var hint := Label.new()
	hint.text = (
		"Each button plays a line as a transmission would: a caller's stinger, then the words, "
		+ "in a low, middle or high voice of the race. A voice's level is for the whole voice."
	)
	hint.theme_type_variation = &"FaintLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)
	var everyone := Button.new()
	everyone.text = "Every voice in turn"
	everyone.focus_mode = Control.FOCUS_NONE
	everyone.theme_type_variation = &"SmallPrimaryButton"
	everyone.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	everyone.pressed.connect(_on_everyone_pressed)
	parent.add_child(everyone)
	for race: Race.Type in VoiceSpeaker.VOICES:
		var voice := VOICE_SCENE.instantiate() as MixerVoice
		voice.setup(race, VoiceSpeaker.VOICES[race], _demo)
		parent.add_child(voice)
		_voices.append(voice)


func _on_everyone_pressed() -> void:
	var entries: Array[Dictionary] = []
	for line: Dictionary in VoiceDemo.LINES:
		if not String(line["label"]) in EVERYONE:
			continue
		for voice: MixerVoice in _voices:
			entries.append(VoiceDemo.entry(voice.race, voice.voice, line))
	_demo.play(entries)


# Stops the sounds the mixer started, but not the music: that is the mixer's backdrop.
func _on_stop_button_pressed() -> void:
	_demo.stop()
	for row: MixerRow in _rows:
		row.stop()


func _on_music_button_pressed() -> void:
	Audio.stop_music(0.3)


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set(table_text())


func _on_reset_button_pressed() -> void:
	for row: MixerRow in _rows:
		row.reset()
	for voice: MixerVoice in _voices:
		voice.reset()


func _on_back_button_pressed() -> void:
	_on_stop_button_pressed()
	SceneFlow.go_to(MAIN_MENU_SCENE)
