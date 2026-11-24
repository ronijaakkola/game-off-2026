class_name FlightSound
extends Node
## The bus's flying sound: [member sound] fades in as the bus starts to fly, loops while it
## does, and fades out when it stops, always at its own pitch and speed.
## The clip is 4 beats of the music long ([constant Audio.MUSIC_BPM]) and loops as the music
## does, so it starts in the middle of the clip where the music is in its bar, not at the
## top of it, and the two stay together. The music plays through a pause and the sound
## doesn't, so it finds its place again once the game resumes.

## How many beats long the clip is.
const CLIP_BEATS := 4.0

## The clip, 4 beats long. Its import loops it.
@export var sound: AudioStream
## The bus whose flight it follows.
@export var bus: FrameshiftBus
## Seconds the sound takes to fade in as the bus starts to fly, and to fade out as it stops.
@export_range(0.0, 2.0, 0.01) var fade_in_seconds := 0.5
@export_range(0.0, 2.0, 0.01) var fade_out_seconds := 0.5

var _player: AudioStreamPlayer
var _flying := false
var _fade: Tween


func _ready() -> void:
	# Its own player, not Audio.play_sfx: the sound has to stop when the flight does.
	_player = AudioStreamPlayer.new()
	_player.stream = sound
	_player.bus = Audio.BUS_NAMES[Audio.Bus.SFX]
	add_child(_player)


func _notification(what: int) -> void:
	# The music carried on through the pause and the clip didn't, so it takes its place again.
	if what == NOTIFICATION_UNPAUSED and _flying and _player:
		_player.stop()
		_fade_to(Audio.get_clip_volume(sound), fade_in_seconds, true)


func _process(_delta: float) -> void:
	var flying := bus != null and bus.state == FrameshiftBus.State.FLYING
	if flying != _flying:
		_set_flying(flying)


## Whether the bus is flying, so the sound is meant to be heard. It fades out after.
func is_flying() -> bool:
	return _flying


func _set_flying(flying: bool) -> void:
	_flying = flying
	if flying:
		_fade_to(Audio.get_clip_volume(sound), fade_in_seconds, true)
	elif _player.playing:
		_fade_to(0.0, fade_out_seconds, false)


# Fades the player to [param volume] over [param seconds], starting the clip at the music's
# place in it first if it isn't playing, and stopping it once faded out. A clip still fading
# out is already in place, so it fades back in from where it is.
func _fade_to(volume: float, seconds: float, playing: bool) -> void:
	if not sound:
		return
	if _fade:
		_fade.kill()
	if playing and not _player.playing:
		_player.volume_linear = 0.0
		_player.play(_music_place())
	_fade = create_tween()
	_fade.tween_property(_player, ^"volume_linear", volume, seconds)
	if not playing:
		_fade.tween_callback(_player.stop)


# Seconds into the clip where the music is in its 4 beats, so the clip starts in step. 0
# when no music plays.
func _music_place() -> float:
	var length := sound.get_length()
	return fposmod(length - Audio.seconds_to_beat(CLIP_BEATS), length)
