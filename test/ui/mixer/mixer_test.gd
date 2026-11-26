extends GdUnitTestSuite

const DOCK_BELL := "game/bus/dock_bell.ogg"
const BG := preload("res://ui/audio/bgm1.ogg")
const RINGTONE := preload("res://game/solar_system/ringtone.ogg")
const BELL := preload("res://game/bus/dock_bell.ogg")


# The mixer's edits last the run, so a test puts back what it moved.
func after_test() -> void:
	for path: String in ClipLevels.LEVELS:
		Audio.set_clip_volume(load("res://" + path), ClipLevels.LEVELS[path])
	for voice: Voice in VoiceSpeaker.VOICES.values():
		voice.volume = (
			(
				ResourceLoader.load(voice.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
				as Voice
			)
			. volume
		)


func test_the_mixer_lists_every_clip_but_the_voices() -> void:
	var runner := scene_runner("res://ui/mixer/mixer.tscn")
	var rows: Array[Node] = runner.scene().find_children("*", "MixerRow", true, false)
	assert_int(rows.size()).is_equal(ClipFinder.find().size())
	assert_array(ClipFinder.find()).contains([DOCK_BELL, "ui/audio/bgm1.ogg"])
	for path: String in ClipFinder.find():
		(
			assert_bool(path.begins_with("game/transmissions/voice/"))
			. override_failure_message(path)
			. is_false()
		)


func test_music_is_a_track_and_a_ringtone_is_a_loop() -> void:
	assert_bool(ClipFinder.is_track(BG)).is_true()
	assert_bool(ClipFinder.is_track(RINGTONE)).is_false()
	assert_bool(ClipFinder.loops(RINGTONE)).is_true()
	assert_bool(ClipFinder.loops(BELL)).is_false()


func test_setting_a_level_changes_how_loud_the_clip_plays_and_what_copy_gives() -> void:
	var runner := scene_runner("res://ui/mixer/mixer.tscn")
	var mixer := runner.scene() as Mixer
	var row: MixerRow
	for candidate: MixerRow in runner.scene().find_children("*", "MixerRow", true, false):
		if candidate.path == DOCK_BELL:
			row = candidate
	assert_bool(row.is_edited()).is_false()
	(row.find_child("Level") as LevelControl)._take(1.35)
	assert_float(Audio.get_clip_volume(BELL)).is_equal_approx(1.35, 0.001)
	assert_bool(row.is_edited()).is_true()
	assert_str(mixer.table_text()).contains('\t"%s": 1.35,' % DOCK_BELL)
	row.reset()
	assert_float(Audio.get_clip_volume(BELL)).is_equal_approx(ClipLevels.of(BELL), 0.001)
	assert_bool(row.is_edited()).is_false()


func test_a_voice_level_goes_to_its_voice_and_into_copy() -> void:
	var runner := scene_runner("res://ui/mixer/mixer.tscn")
	var mixer := runner.scene() as Mixer
	var voice: MixerVoice = runner.scene().find_children("*", "MixerVoice", true, false)[0]
	(voice.find_child("Level") as LevelControl)._take(1.5)
	assert_float(voice.voice.volume).is_equal_approx(1.5, 0.001)
	assert_bool(voice.is_edited()).is_true()
	assert_str(mixer.table_text()).contains("volume = 1.5")
	voice.reset()
	assert_bool(voice.is_edited()).is_false()


func test_a_level_is_written_with_a_point_and_two_places_at_most() -> void:
	assert_str(Mixer.level_text(1.0)).is_equal("1.0")
	assert_str(Mixer.level_text(0.8)).is_equal("0.8")
	assert_str(Mixer.level_text(0.333)).is_equal("0.33")
	assert_str(Mixer.level_text(2.0)).is_equal("2.0")


func test_a_volume_set_to_zero_in_settings_is_warned_of() -> void:
	var music := Settings.music_volume
	Settings.music_volume = 0.0
	var runner := scene_runner("res://ui/mixer/mixer.tscn")
	var warning := runner.find_child("Silenced") as Label
	assert_bool(warning.visible).is_true()
	assert_str(warning.text).contains("Music")
	Settings.music_volume = 0.6
	assert_array(Mixer.silenced_volumes()).is_empty()
	Settings.music_volume = music
