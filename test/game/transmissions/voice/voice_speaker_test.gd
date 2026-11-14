extends GdUnitTestSuite

const SAMPLE_NAME := "Sufoi"

var _speaker: VoiceSpeaker
var _voice: Voice


func before_test() -> void:
	# A copy of Blue's voice, with the chances taken out, so what plays is certain.
	_voice = VoiceSpeaker.VOICES[Race.Type.BLUE].duplicate() as Voice
	_voice.start_long_chance = 0.0
	_voice.pause_long_chance = 0.0
	_voice.pitch_jitter = 0.0
	_speaker = auto_free(VoiceSpeaker.new()) as VoiceSpeaker
	_speaker.voices[Race.Type.BLUE] = _voice
	add_child(_speaker)
	_speaker.begin(Race.Type.BLUE, SAMPLE_NAME)


func _playing() -> Array[AudioStreamPlayer]:
	var playing: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _speaker._players:
		if player.playing:
			playing.append(player)
	return playing


func test_a_clip_never_repeats_the_last() -> void:
	var rng := RandomNumberGenerator.new()
	var last := -1
	for i: int in 500:
		var index := VoiceSpeaker.pick_index(4, last, rng)
		assert_int(index).is_between(0, 3)
		assert_int(index).is_not_equal(last)
		last = index
	assert_int(VoiceSpeaker.pick_index(1, 0, rng)).is_equal(0)


func test_a_caller_keeps_one_voice_inside_the_range() -> void:
	for name: String in ["Sufoi", "Reizhis", "Mibbo", "Draz", "Olmek"]:
		var step := VoiceSpeaker.voice_step(name, 8)
		assert_int(step).is_between(0, 7)
		assert_int(VoiceSpeaker.voice_step(name, 8)).is_equal(step)
		var pitch := VoiceSpeaker.caller_pitch(name, 0.9, 1.2, 8)
		assert_float(pitch).is_between(0.9, 1.2)
	assert_float(VoiceSpeaker.caller_pitch("any", 0.9, 1.1, 1)).is_equal(1.0)


func test_a_word_is_letters_digits_and_apostrophes() -> void:
	assert_bool(VoiceSpeaker.is_word_letter("a")).is_true()
	assert_bool(VoiceSpeaker.is_word_letter("Z")).is_true()
	assert_bool(VoiceSpeaker.is_word_letter("7")).is_true()
	assert_bool(VoiceSpeaker.is_word_letter("'")).is_true()
	assert_bool(VoiceSpeaker.is_word_letter(" ")).is_false()
	assert_bool(VoiceSpeaker.is_word_letter(",")).is_false()
	assert_bool(VoiceSpeaker.is_word_letter("?")).is_false()


func test_it_finds_where_the_words_after_start() -> void:
	var text := "Hello there driver, are you"
	assert_int(_speaker._word_after(text, 5, 1)).is_equal(text.find("there"))
	assert_int(_speaker._word_after(text, 5, 2)).is_equal(text.find("driver"))
	assert_int(_speaker._word_after(text, 5, 4)).is_equal(text.find("you"))
	assert_int(_speaker._word_after(text, 5, 9)).is_equal(text.length())


func test_a_word_gets_a_blip_as_it_starts() -> void:
	_speaker.letter("Hello there", 0)
	var playing := _playing()
	assert_int(playing.size()).is_equal(1)
	assert_bool(_voice.blips.has(playing[0].stream)).is_true()


func test_a_short_word_gets_none() -> void:
	_speaker.letter("Is it", 0)
	assert_int(_playing().size()).is_equal(0)


func test_no_voice_is_silent() -> void:
	_speaker.begin(Race.Type.GREEN, "Zhenn")
	assert_object(_speaker.voice).is_null()
	_speaker.letter("Hello there", 0)
	assert_int(_playing().size()).is_equal(0)
	assert_float(_speaker.get_caller_pitch()).is_equal(1.0)
	assert_float(_speaker.get_typing_speed()).is_equal(1.0)


func test_the_word_before_a_question_mark_gets_its_ending() -> void:
	var text := "Is it you?"
	_speaker.letter(text, text.find("you"))
	var playing := _playing()
	assert_int(playing.size()).is_equal(1)
	assert_bool(_voice.questions.has(playing[0].stream)).is_true()


func test_the_word_before_an_exclamation_mark_gets_its_ending() -> void:
	var text := "Look out!"
	_speaker.letter(text, text.find("out"))
	var playing := _playing()
	assert_int(playing.size()).is_equal(1)
	assert_bool(_voice.exclaims.has(playing[0].stream)).is_true()


func test_a_blip_can_cover_several_words() -> void:
	_voice.words_per_blip_min = 3
	_voice.words_per_blip_max = 3
	var text := "Hello there driver, are you ready"
	_speaker.letter(text, 0)
	assert_int(_speaker._covered_until).is_equal(text.find("are"))
	var before := _speaker._ends.duplicate()
	_speaker.letter(text, text.find("there"))
	_speaker.letter(text, text.find("driver"))
	assert_array(_speaker._ends).is_equal(before)


func test_blip_speed_speeds_the_clip_up() -> void:
	_voice.blip_speed = 1.5
	_speaker.letter("Hello there", 0)
	var expected := clampf(_speaker.get_caller_pitch() * 1.5, 0.5, 2.0)
	assert_float(_playing()[0].pitch_scale).is_equal_approx(expected, 0.001)


func test_a_long_clip_holds_the_blips_off() -> void:
	_voice.start_long_chance = 1.0
	var text := "Hello there driver"
	_speaker.letter(text, 0)
	var playing := _playing()
	assert_int(playing.size()).is_equal(1)
	assert_bool(_voice.longs.has(playing[0].stream)).is_true()
	_speaker.letter(text, text.find("there"))
	assert_int(_playing().size()).is_equal(1)


func test_stop_silences_it() -> void:
	_speaker.letter("Hello there", 0)
	_speaker.stop()
	assert_int(_playing().size()).is_equal(0)
