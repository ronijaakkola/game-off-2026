class_name Voice
extends Resource
## How one race sounds when a caller talks: its clips, and how a [VoiceSpeaker] strings
## them together while the text types out. The numbers under Delivery are what the voice
## lab (game/transmissions/voice_lab.tscn) tunes.

## The moods a stinger can have.
enum Stinger { ANNOYED = 0, HAPPY = 1, SCARED = 2 }

@export_group("Clips")
## The base blips, one for a word.
@export var blips: Array[AudioStream] = []
## The rising tail of the word before a question mark.
@export var questions: Array[AudioStream] = []
## The sharp, loud sound on the word before an exclamation mark.
@export var exclaims: Array[AudioStream] = []
## Longer blips, at the start of a line and sometimes at a comma or a full stop.
@export var longs: Array[AudioStream] = []
## The sound a call opens with, by the caller's mood.
@export var stingers_annoyed: Array[AudioStream] = []
@export var stingers_happy: Array[AudioStream] = []
@export var stingers_scared: Array[AudioStream] = []

@export_group("Delivery")
## How fast the text types out for this race, as a multiple of the usual pace: above 1 is
## faster. A race's language can run quicker or slower than another's. It takes hold the
## next time a line starts.
@export_range(0.4, 2.5, 0.01) var typing_speed := 1.0
## How loud the voice is, 1 as recorded, up to 2 (the mixer sets it).
@export_range(0.0, 2.0, 0.01) var volume := 1.0
## The lowest and highest pitch a caller's voice has, 1 as recorded. The range is split into
## [member voice_count] steps, and each caller's name picks one, so callers of a race sound
## clearly different, not a hair apart.
@export_range(0.5, 2.0, 0.01) var pitch_min := 0.9
@export_range(0.5, 2.0, 0.01) var pitch_max := 1.1
## How many steps the pitch range is split into.
@export_range(1, 16, 1) var voice_count := 6
## How much each blip's pitch varies at random either way, as a share (0.07 is ±7 %). Keep
## it well under half a step of the range, or the voices blur into each other.
@export_range(0.0, 0.3, 0.005) var pitch_jitter := 0.07
## How fast blips play, as a multiple of their recorded speed: above 1 is shorter. The web
## has no time-stretch, so this raises their pitch the same way as the pitch above, on top
## of it.
@export_range(0.5, 2.0, 0.01) var blip_speed := 1.0
## How many words one blip covers, at random between these two. The blip is picked to fit the
## time up to the word after them, and the words between get none of their own.
@export_range(1, 4, 1) var words_per_blip_min := 1
@export_range(1, 4, 1) var words_per_blip_max := 1
## How much a blip may be sped up to fit the words it covers, as a multiple. 1 takes only
## clips that already fit; 1.3 also takes clips up to 30 % too long and plays them faster, and
## so higher, to fit.
@export_range(1.0, 2.0, 0.01) var fit_speed := 1.0
## A word gets a blip as it starts if it has at least this many letters, and a second one
## halfway if it has at least [member long_word_letters]. Make the second number large to
## turn the second blip off.
@export_range(1, 8, 1) var min_word_letters := 3
@export_range(2, 16, 1) var long_word_letters := 8
## How far a clip may start before the one playing ends, in seconds, so two stack a little.
## A blip that would overlap more is skipped, and a question, exclamation or long clip fades
## out what it would overlap more.
@export_range(0.0, 0.4, 0.005) var max_overlap := 0.18
## How long each clip takes to fade in and out, in seconds. The clips start and end on
## sound, so a little of both keeps them from clicking.
@export_range(0.0, 0.05, 0.001) var fade_in := 0.006
@export_range(0.0, 0.1, 0.001) var fade_out := 0.025
## The chance a long clip plays as a line starts, and at a comma or a full stop.
@export_range(0.0, 1.0, 0.01) var start_long_chance := 0.5
@export_range(0.0, 1.0, 0.01) var pause_long_chance := 0.3
## The silence after a long clip or a stinger before blips resume, in seconds.
@export_range(0.0, 1.0, 0.01) var long_pause := 0.15


## The clips of [param stinger]'s mood.
func get_stingers(stinger: Stinger) -> Array[AudioStream]:
	match stinger:
		Stinger.ANNOYED:
			return stingers_annoyed
		Stinger.HAPPY:
			return stingers_happy
	return stingers_scared
