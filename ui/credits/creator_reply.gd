class_name CreatorReply
extends Node
## How one of the people on the credits answers a tap on their photo: a happy sound in their
## race's [Voice] and a beaming face. Tapped again and again, they sound and look annoyed.

## Each creator's pitch, as a multiple of their race's voice as recorded.
const PITCHES: Dictionary[CreatorPortrait.Creator, float] = {
	CreatorPortrait.Creator.RONI: 1.0,
	CreatorPortrait.Creator.MARKO: 0.8,
	CreatorPortrait.Creator.SAMI: 0.7,
}
## Henna's, higher than Sami's in the same voice.
const GUEST_PITCH := 1.25
## Taps no further apart than this, in seconds, count as one run of them, and from this tap
## of a run on they are annoyed.
const RUN_SECONDS := 2.5
const ANNOYED_FROM := 4
## How long the face holds after a tap, in seconds.
const FACE_SECONDS := 1.4
## How angry they look then: past half, so the anger mark pops up.
const ANNOYED_ANGER := 0.7

## How joyful they look while not answering a tap.
var resting_joy := 0.0

var _portrait: AlienPortrait
var _race: Race.Type
var _speaker := VoiceSpeaker.new()
var _taps := 0
var _run_left := 0.0
var _face_left := 0.0


## Takes [param portrait], in place, which answers in [param race]'s voice at
## [param pitch].
func setup(portrait: AlienPortrait, race: Race.Type, pitch: float) -> void:
	_portrait = portrait
	_race = race
	# A copy with the one pitch, so it doesn't hang on a caller's name.
	var voice := VoiceSpeaker.VOICES[race].duplicate() as Voice
	voice.pitch_min = pitch
	voice.pitch_max = pitch
	voice.voice_count = 1
	_speaker.voices[race] = voice
	add_child(_speaker)


## Answers a tap, cutting off their last answer.
func answer() -> void:
	_taps = _taps + 1 if _run_left > 0.0 else 1
	_run_left = RUN_SECONDS
	_face_left = FACE_SECONDS
	_speaker.begin(_race, name)
	_speaker.play_stinger(Voice.Stinger.ANNOYED if _is_annoyed() else Voice.Stinger.HAPPY)
	_show_face()


## Hushes them at once and forgets the taps so far.
func reset() -> void:
	_speaker.stop()
	_taps = 0
	_run_left = 0.0
	_face_left = 0.0
	_show_face()


func _process(delta: float) -> void:
	if not _portrait:
		return
	_run_left = maxf(_run_left - delta, 0.0)
	_face_left = maxf(_face_left - delta, 0.0)
	_show_face()


func _is_annoyed() -> bool:
	return _taps >= ANNOYED_FROM


func _show_face() -> void:
	var answering := _face_left > 0.0
	var annoyed := answering and _is_annoyed()
	_portrait.anger = ANNOYED_ANGER if annoyed else 0.0
	if annoyed:
		_portrait.joy = 0.0
	else:
		_portrait.joy = 1.0 if answering else resting_joy
