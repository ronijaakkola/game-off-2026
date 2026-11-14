extends GdUnitTestSuite


func test_a_caller_has_the_voice_asked_for() -> void:
	for count: int in [4, 6, 12]:
		for step: int in count:
			var caller := VoiceDemo.caller_for(count, step)
			assert_int(VoiceSpeaker.voice_step(caller, count)).is_equal(step)


func test_a_line_is_said_by_a_low_middle_or_high_voice_of_the_race() -> void:
	var voice := VoiceSpeaker.VOICES[Race.Type.BLUE]
	var steps: Array[int] = []
	for line: Dictionary in VoiceDemo.LINES:
		var entry := VoiceDemo.entry(Race.Type.BLUE, voice, line)
		assert_int(entry["race"]).is_equal(Race.Type.BLUE)
		assert_str(entry["text"]).is_equal(line["text"])
		steps.append(VoiceSpeaker.voice_step(entry["caller"], voice.voice_count))
	assert_int(steps.min()).is_equal(0)
	assert_int(steps.max()).is_equal(voice.voice_count - 1)


func test_lines_are_said_one_after_another_and_it_finishes() -> void:
	var demo := auto_free(VoiceDemo.new()) as VoiceDemo
	add_child(demo)
	var voice := VoiceSpeaker.VOICES[Race.Type.BLUE]
	var entries: Array[Dictionary] = []
	for i: int in 2:
		var entry := VoiceDemo.entry(Race.Type.BLUE, voice, VoiceDemo.LINES[0])
		entry["text"] = "Hi."
		entries.append(entry)
	var done := [false]
	demo.finished.connect(func() -> void: done[0] = true)
	demo.play(entries)
	assert_bool(demo.is_playing()).is_true()
	# Drive it by hand: a second's steps, enough for two short lines and their gaps.
	for i: int in 100:
		demo._process(0.1)
	assert_bool(done[0]).is_true()
	assert_bool(demo.is_playing()).is_false()
