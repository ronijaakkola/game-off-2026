class_name Psst
extends RefCounted
## The "psst" a passenger makes as they ask for something: one of [constant CLIPS] at
## random, never the one before, whoever asks, its pitch varied a little.

const CLIPS: Array[AudioStream] = [
	preload("res://game/passengers/psst_1.ogg"),
	preload("res://game/passengers/psst_2.ogg"),
	preload("res://game/passengers/psst_3.ogg"),
]
## How much the pitch varies at random (0.06 is ±6%), so the same clip doesn't sound the
## same twice.
const PITCH_JITTER := 0.06

static var _last := -1


## Plays one of the clips.
static func play() -> void:
	var index := randi_range(0, CLIPS.size() - 1)
	if index == _last:
		index = (index + randi_range(1, CLIPS.size() - 1)) % CLIPS.size()
	_last = index
	Audio.play_sfx(CLIPS[index], PITCH_JITTER)
