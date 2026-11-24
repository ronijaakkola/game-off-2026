class_name VoiceDemo
extends Node
## Plays a caller's line as it plays in a transmission, for the mixer: the real
## [VoiceSpeaker] is fed the text's letters at the speaking pace, after the stinger a mood
## opens with. [method play] takes lines to say one after another.

## Emitted once the last line has been said.
signal finished

## Seconds from a stinger to the first word, as in a transmission, and the gap between lines.
const LEAD_SECONDS := 0.6
const GAP_SECONDS := 0.8
## Seconds a kicked scream has to fade out before the next line.
const KICKED_SECONDS := 2.5
## The lines to hear a voice in. A caller is "low", "mid" or "high": the lowest, middle or
## highest of the race's pitch steps.
const LINES: Array[Dictionary] = [
	{
		"label": "Plain",
		"caller": "mid",
		"mood": Passenger.Mood.OKAY,
		"text": "Hello there, driver. I am going to the Giant, and I am a little late.",
	},
	{
		"label": "Question",
		"caller": "mid",
		"mood": Passenger.Mood.OKAY,
		"text": "Are you taking the long way round? Is that really the Giant ahead?",
	},
	{
		"label": "Exclaim",
		"caller": "mid",
		"mood": Passenger.Mood.OKAY,
		"text": "Watch out! That moon is right in front of us! Stop the bus!",
	},
	{
		"label": "Annoyed",
		"caller": "mid",
		"mood": Passenger.Mood.ANNOYED,
		"text": "This is the third time we have stopped. I have somewhere to be, driver.",
	},
	{
		"label": "Happy",
		"caller": "mid",
		"mood": Passenger.Mood.HAPPY,
		"text": "Oh, what a lovely ride! Thank you, driver, thank you so much!",
	},
	{
		"label": "Scared",
		"caller": "mid",
		"mood": Passenger.Mood.OKAY,
		"scared": true,
		"text": "Please, no. Not the black hole, I beg you. Turn the bus around!",
	},
	{
		"label": "Kicked",
		"caller": "mid",
		"mood": Passenger.Mood.OKAY,
		"kicked": true,
		"text": "",
	},
	{
		"label": "Low voice",
		"caller": "low",
		"mood": Passenger.Mood.OKAY,
		"text": "Hello there, driver. I am going to the Giant, and I am a little late.",
	},
	{
		"label": "High voice",
		"caller": "high",
		"mood": Passenger.Mood.OKAY,
		"text": "Hello there, driver. I am going to the Giant, and I am a little late.",
	},
]

var _speaker: VoiceSpeaker
var _queue: Array[Dictionary] = []
var _text := ""
var _index := 0
# Seconds until the next letter shows, or, once all have, until the next line.
var _wait := 0.0
var _saying := false


func _ready() -> void:
	_speaker = VoiceSpeaker.new()
	add_child(_speaker)
	set_process(false)


func _process(delta: float) -> void:
	_wait -= delta
	while _wait <= 0.0:
		if _saying:
			_speaker.letter(_text, _index)
			_wait += TalkPace.wait_after(_text[_index]) / _speaker.get_typing_speed()
			_index += 1
			if _index >= _text.length():
				_saying = false
				_wait += GAP_SECONDS
		else:
			_next()
			return


## A caller's name that gives the voice at [param step] of [param count], counted from 0.
static func caller_for(count: int, step: int) -> String:
	for i: int in 1000:
		var caller_name := "Caller %d" % i
		if VoiceSpeaker.voice_step(caller_name, count) == step:
			return caller_name
	return "Caller"


## The line [param line] of [constant LINES], said by a caller of [param race], as a thing for
## [method play].
static func entry(race: Race.Type, voice: Voice, line: Dictionary) -> Dictionary:
	var steps: Dictionary[String, int] = {
		"low": 0, "mid": voice.voice_count / 2, "high": voice.voice_count - 1
	}
	var step: int = steps[line["caller"]]
	return {
		"race": race,
		"caller": caller_for(voice.voice_count, step),
		"mood": line["mood"],
		"scared": line.get("scared", false),
		"kicked": line.get("kicked", false),
		"text": line["text"],
	}


## Says [param entries], one after another, in place of anything being said.
func play(entries: Array[Dictionary]) -> void:
	stop()
	_queue = entries.duplicate()
	_next()


## Whether a line is being said.
func is_playing() -> bool:
	return is_processing()


## Cuts off whatever is being said.
func stop() -> void:
	_queue.clear()
	_saying = false
	_speaker.stop()
	set_process(false)


func _next() -> void:
	if _queue.is_empty():
		set_process(false)
		finished.emit()
		return
	var line: Dictionary = _queue.pop_front()
	var race: Race.Type = line["race"]
	_speaker.begin(race, line["caller"])
	if line["kicked"]:
		_speaker.play_kicked()
		_text = ""
		_saying = false
		_wait = KICKED_SECONDS
		set_process(true)
		return
	if line["scared"]:
		_speaker.play_stinger(Voice.Stinger.SCARED)
	else:
		_speaker.play_mood(line["mood"])
	_text = line["text"]
	_index = 0
	_wait = LEAD_SECONDS
	_saying = true
	set_process(true)
