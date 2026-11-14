class_name VoiceSpeaker
extends Node
## Gives a caller their race's [Voice] while their text types out, like a talking game does:
## each letter shown is reported with [method letter], and each word gets a blip as it starts,
## picked to fit the time before the next word. The word before a question or exclamation
## mark gets that mark's clip instead, timed to end as the mark shows, and a long clip may
## open the line or sit at a comma or a full stop. It picks a random clip each time and never
## the same twice in a row, varies the pitch a little, and gives each caller one of the race's
## voice steps from their name, so callers of a race sound clearly different but still of it.
## A clip may start up to [member Voice.max_overlap] before the one playing ends, on a second
## player, so two stack a little; a blip that would stack more is skipped, and an ending or a
## long clip fades out what it would stack on more. Every clip fades in and out a little. A
## race with no voice is silent.

## Each race's voice.
const VOICES: Dictionary[Race.Type, Voice] = {
	Race.Type.BLUE: preload("res://game/transmissions/voice/blue.tres"),
	Race.Type.ORANGE: preload("res://game/transmissions/voice/orange.tres"),
}
## The lowest and highest rate a clip plays at.
const MIN_PITCH := 0.5
const MAX_PITCH := 2.0
## The kind a blip's last clip is kept under.
const BLIP := &"blip"
## Seconds a clip fades out over when an ending or a long clip cuts in on it.
const CUT_FADE := 0.08

## Each race's voice in use. It starts as [constant VOICES]; a lab swaps in copies to tune,
## so the saved files stay as they are.
var voices: Dictionary[Race.Type, Voice] = VOICES.duplicate()
## The voice talking now, or null.
var voice: Voice

var _caller_name := ""
# The clip that played last of each kind, so no clip plays twice running.
var _last: Dictionary[StringName, int] = {}
# Two players that take turns, each with the tween shaping its clip and the time its clip
# ends, in seconds since the game started.
var _players: Array[AudioStreamPlayer] = []
var _shapes: Array[Tween] = [null, null]
var _ends: Array[float] = [0.0, 0.0]
var _turn := 0
# No blips until a long clip, or a stinger, is over.
var _quiet_until := 0.0
# The letter of a long word where its second blip sounds, and the time it has.
var _second_at := -1
var _second_slot := 0.0
# The letter where the words the last blip covers end: words starting before it get no blip.
var _covered_until := 0
# An ending waiting for its moment, and when that is.
var _due_clip: AudioStream
var _due_at := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = Audio.BUS_NAMES[Audio.Bus.SFX]
		add_child(player)
		_players.append(player)
	set_process(false)


func _process(_delta: float) -> void:
	if _now() >= _due_at:
		set_process(false)
		_sound(_due_clip, 1.0, true)


## Which of [param count] clips plays next: any but [param last], or the only one.
static func pick_index(count: int, last: int, rng: RandomNumberGenerator) -> int:
	if count <= 1:
		return 0
	var index := rng.randi_range(0, count - 2)
	return index + 1 if index >= last else index


## Which of [param count] voice steps [param caller_name] has, from 0, the same every time.
static func voice_step(caller_name: String, count: int) -> int:
	return caller_name.hash() % maxi(count, 1)


## The pitch of [param caller_name]'s voice: one of [param count] steps spread evenly from
## [param pitch_min] to [param pitch_max].
static func caller_pitch(
	caller_name: String, pitch_min: float, pitch_max: float, count: int
) -> float:
	if count <= 1:
		return (pitch_min + pitch_max) / 2.0
	return lerpf(pitch_min, pitch_max, float(voice_step(caller_name, count)) / (count - 1))


## Whether [param letter] belongs to a word.
static func is_word_letter(letter: String) -> bool:
	return letter == "'" or letter.to_lower() != letter.to_upper() or letter.is_valid_int()


## Starts a line for [param caller_name] of [param race], in that race's voice.
func begin(race: Race.Type, caller_name: String) -> void:
	voice = voices.get(race)
	_caller_name = caller_name
	_second_at = -1
	_covered_until = 0
	_quiet_until = 0.0
	set_process(false)


## The pitch of the current caller's voice, 1 with no voice.
func get_caller_pitch() -> float:
	if not voice:
		return 1.0
	return caller_pitch(_caller_name, voice.pitch_min, voice.pitch_max, voice.voice_count)


## Which of the race's voices the current caller has, counted from 1, and 0 with no voice.
func get_caller_voice() -> int:
	return voice_step(_caller_name, voice.voice_count) + 1 if voice else 0


## How fast the current voice's text types, as a multiple of the usual pace, 1 with no voice.
func get_typing_speed() -> float:
	return voice.typing_speed if voice else 1.0


## The letter at [param index] of [param text] has just shown.
func letter(text: String, index: int) -> void:
	if not voice or index < 0 or index >= text.length():
		return
	if index == _second_at:
		_second_at = -1
		_blip(_second_slot)
	var starts_word := is_word_letter(text[index])
	if starts_word and index > 0:
		starts_word = not is_word_letter(text[index - 1])
	if starts_word:
		_word(text, index)
	elif text[index] in [".", ",", ";", ":", "—"] and _rng.randf() < voice.pause_long_chance:
		_long()


## Plays a stinger of [param mood]'s kind: annoyed or furious callers sound annoyed, happy
## ones happy. An okay caller has none.
func play_mood(mood: Passenger.Mood) -> void:
	match mood:
		Passenger.Mood.ANNOYED, Passenger.Mood.FURIOUS:
			play_stinger(Voice.Stinger.ANNOYED)
		Passenger.Mood.HAPPY:
			play_stinger(Voice.Stinger.HAPPY)


## Plays one of the current voice's stingers of [param stinger]'s kind, in the caller's pitch.
func play_stinger(stinger: Voice.Stinger) -> void:
	if not voice:
		return
	var clips := voice.get_stingers(stinger)
	if clips.is_empty():
		return
	stop()
	var index := _pick(clips, StringName("stinger%d" % stinger))
	_quiet_until = _now() + _sound(clips[index], 1.0, false) + voice.long_pause


## Cuts off whatever sounds, at once.
func stop() -> void:
	for i: int in _players.size():
		if _shapes[i]:
			_shapes[i].kill()
		_players[i].stop()
		_ends[i] = 0.0
	set_process(false)
	_second_at = -1
	_covered_until = 0
	_quiet_until = 0.0


# A word starts at [param start] of [param text]: its blip, or its ending, or the line's
# opening long clip.
func _word(text: String, start: int) -> void:
	var end := start
	while end < text.length() and is_word_letter(text[end]):
		end += 1
	var next := end
	while next < text.length() and not is_word_letter(text[next]):
		next += 1
	if text.left(start).strip_edges().is_empty() and _rng.randf() < voice.start_long_chance:
		_long()
	var after := text[end] if end < text.length() else ""
	if after == "?" and _ending(voice.questions, &"question", _seconds(text, start, end)):
		return
	if after == "!" and _ending(voice.exclaims, &"exclaim", _seconds(text, start, end)):
		return
	if end - start < voice.min_word_letters or start < _covered_until:
		return
	var covers := _rng.randi_range(
		voice.words_per_blip_min, maxi(voice.words_per_blip_min, voice.words_per_blip_max)
	)
	var until := _word_after(text, end, covers)
	var slot := _seconds(text, start, until)
	if not _blip(slot):
		return
	_covered_until = until
	if covers == 1 and end - start >= voice.long_word_letters:
		_second_at = start + (end - start) / 2
		_second_slot = slot / 2.0


# Where the [param count]th word after [param from] starts in [param text], or the text's end.
func _word_after(text: String, from: int, count: int) -> int:
	var pos := from
	for i: int in count:
		while pos < text.length() and not is_word_letter(text[pos]):
			pos += 1
		if i < count - 1:
			while pos < text.length() and is_word_letter(text[pos]):
				pos += 1
	return pos


# How long the text takes to type from [param from] up to [param to], at this voice's speed.
func _seconds(text: String, from: int, to: int) -> float:
	var total := 0.0
	for i: int in range(from, to):
		total += TalkPace.wait_after(text[i])
	return total / voice.typing_speed


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# How long until the clip playing longest ends, 0 when none plays.
func _remaining() -> float:
	return maxf(maxf(_ends[0], _ends[1]) - _now(), 0.0)


func _pick(clips: Array[AudioStream], key: StringName) -> int:
	var index := pick_index(clips.size(), _last.get(key, -1), _rng)
	_last[key] = index
	return index


# A blip for the words that take [param slot] seconds before the next sound: a clip short
# enough to fit, or one up to [member Voice.fit_speed] too long, played faster to fit. Not if
# the clip playing would be stacked on more than allowed, or a long clip is still on. Returns
# whether it played.
func _blip(slot: float) -> bool:
	if voice.blips.is_empty() or _now() < _quiet_until:
		return false
	var remaining := _remaining()
	if remaining > voice.max_overlap:
		return false
	var rate := get_caller_pitch() * voice.blip_speed
	var room := maxf(slot + voice.max_overlap - remaining, 0.01)
	var fits: Array[int] = []
	var shortest := 0
	for i: int in voice.blips.size():
		var length := voice.blips[i].get_length()
		if length < voice.blips[shortest].get_length():
			shortest = i
		if length / rate / room <= voice.fit_speed and i != _last.get(BLIP, -1):
			fits.append(i)
	var index := fits[_rng.randi_range(0, fits.size() - 1)] if not fits.is_empty() else shortest
	_last[BLIP] = index
	var squeeze := clampf(voice.blips[index].get_length() / rate / room, 1.0, voice.fit_speed)
	_sound(voice.blips[index], voice.blip_speed * squeeze, true)
	return true


# A long clip now, which holds the blips off until it is over.
func _long() -> void:
	if voice.longs.is_empty():
		return
	var index := _pick(voice.longs, &"long")
	_quiet_until = _now() + _sound(voice.longs[index], 1.0, true, true) + voice.long_pause


# The ending for the word before a question or exclamation mark, timed to end as the mark
# shows, [param lead] seconds after the word starts. Returns whether there was a clip.
func _ending(clips: Array[AudioStream], key: StringName, lead: float) -> bool:
	if clips.is_empty():
		return false
	var index := _pick(clips, key)
	var delay := lead - clips[index].get_length() / get_caller_pitch()
	if delay < 0.02:
		_sound(clips[index], 1.0, true, true)
		return true
	_due_clip = clips[index]
	_due_at = _now() + delay
	set_process(true)
	return true


# Plays [param clip] at the caller's pitch times [param speed], with a little random variation
# if [param varied], on the next player, and returns how long it lasts. With [param cutting],
# a clip still playing past [member Voice.max_overlap] fades out.
func _sound(clip: AudioStream, speed: float, varied: bool, cutting := false) -> float:
	var now := _now()
	if cutting:
		for i: int in 2:
			if _ends[i] - now > voice.max_overlap:
				_cut(i)
	var pitch := get_caller_pitch() * speed
	if varied:
		pitch *= 1.0 + _rng.randf_range(-voice.pitch_jitter, voice.pitch_jitter)
	pitch = clampf(pitch, MIN_PITCH, MAX_PITCH)
	var seconds := clip.get_length() / pitch
	var i := _turn
	_turn = 1 - _turn
	var player := _players[i]
	if _shapes[i]:
		_shapes[i].kill()
	player.stream = clip
	player.pitch_scale = pitch
	player.volume_linear = 0.0 if voice.fade_in > 0.0 else voice.volume
	player.play()
	_ends[i] = now + seconds
	var shape := create_tween()
	if voice.fade_in > 0.0:
		shape.tween_property(player, "volume_linear", voice.volume, voice.fade_in)
	shape.tween_interval(maxf(seconds - voice.fade_in - voice.fade_out, 0.0))
	shape.tween_property(player, "volume_linear", 0.0, voice.fade_out)
	_shapes[i] = shape
	return seconds


# Fades the clip on player [param i] out quickly and stops it.
func _cut(i: int) -> void:
	if _shapes[i]:
		_shapes[i].kill()
	var shape := create_tween()
	shape.tween_property(_players[i], "volume_linear", 0.0, CUT_FADE)
	shape.tween_callback(_players[i].stop)
	_shapes[i] = shape
	_ends[i] = _now() + CUT_FADE
