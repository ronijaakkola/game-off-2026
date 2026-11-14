extends Node
## Music and sound effects. Music crossfades between two players, one track at a time.
## Sound effects take turns on a pool of players. It processes always, so music keeps
## playing while the game is paused. It owns the mixer's buses: code names a bus as an
## [enum Bus], never by its name. The music plays on the Muffle bus, which feeds Music:
## [method muffle_music] eases a low-pass filter and a duck in on it, so the Music volume
## stays the player's setting.

## The buses in core/audio/default_bus_layout.tres.
enum Bus { MASTER, MUSIC, SFX, MUFFLE }

const SFX_PLAYERS := 8
## Each [enum Bus]'s name in default_bus_layout.tres. Set an AudioStreamPlayer's bus from it:
## [code]player.bus = Audio.BUS_NAMES[Audio.Bus.SFX][/code].
const BUS_NAMES: Dictionary[Bus, StringName] = {
	Bus.MASTER: &"Master",
	Bus.MUSIC: &"Music",
	Bus.SFX: &"SFX",
	Bus.MUFFLE: &"Muffle",
}
## The muffle's low-pass cutoff when off and fully on, in hertz, and how loud the music
## stays fully muffled. Web audio has no bus effects, so on the web only the duck is heard.
const OPEN_CUTOFF := 20000.0
const MUFFLED_CUTOFF := 700.0
const MUFFLED_VOLUME := 0.6
## Seconds the muffle takes to come in and to go.
const MUFFLE_IN_SECONDS := 0.4
const MUFFLE_OUT_SECONDS := 0.6
## The music's tempo, in beats a minute, for sounds that land on its beat.
const MUSIC_BPM := 88.0

var _music_players: Array[AudioStreamPlayer] = []
var _music_tweens: Array[Tween] = [null, null]
var _current := 0
var _music: AudioStream
# Levels the mixer has set this run, by the clip's path, over the table in ClipLevels.
var _levels: Dictionary[String, float] = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
# How muffled the music is, from 0 to 1, and the one tween that moves it.
var _muffle := 0.0
var _muffling: Tween


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for i: int in 2:
		_music_players.append(_add_player(Bus.MUFFLE))
	for i: int in SFX_PLAYERS:
		_sfx_players.append(_add_player(Bus.SFX))


## Crossfades to [param stream] over [param fade] seconds. Asking for the track
## that's already playing does nothing.
func play_music(stream: AudioStream, fade := 1.0) -> void:
	if stream == _music:
		return
	_music = stream
	_fade_out(_current, fade)
	_current = 1 - _current
	var player := _music_players[_current]
	player.stream = stream
	player.volume_linear = 0.0
	player.play()
	_fade(_current, get_clip_volume(stream), fade)


## Seconds until the music's next beat, or the next [param beats]th beat of it (0.5 for every
## half beat, 2 for every other). 0 when no music is playing, so a sound meant to land on
## the beat plays at once. The music is on a grid from the start of its file, which its
## loop keeps ([constant MUSIC_BPM]).
func seconds_to_beat(beats := 1.0) -> float:
	var player := _music_players[_current]
	if not player.playing:
		return 0.0
	var step := 60.0 / MUSIC_BPM * beats
	# A mix is not made every frame, so the position lags by the time since the last one.
	var position := player.get_playback_position() + AudioServer.get_time_since_last_mix()
	return fposmod(-position, step)


## Fades the music out over [param fade] seconds.
func stop_music(fade := 1.0) -> void:
	_music = null
	_fade_out(_current, fade)


## Eases the music into sounding muffled, as if heard through a wall, or back out of it,
## from wherever it is, so it never snaps.
func muffle_music(muffled: bool) -> void:
	if _muffling:
		_muffling.kill()
	_muffling = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var seconds := MUFFLE_IN_SECONDS if muffled else MUFFLE_OUT_SECONDS
	_muffling.tween_method(_set_muffle, _muffle, 1.0 if muffled else 0.0, seconds)


## How muffled the music is, from 0 (clear) to 1 (fully muffled).
func get_muffle() -> float:
	return _muffle


## How loud [param stream] plays, as a multiple of how it was recorded: 1 as recorded, up to
## [constant ClipLevels.MAX]. Its default in [ClipLevels], or what the mixer has set it to
## since the game started. A sound that makes its own player sets that player's volume to
## this; [method play_music] and [method play_sfx] do it themselves.
func get_clip_volume(stream: AudioStream) -> float:
	if stream and _levels.has(stream.resource_path):
		return _levels[stream.resource_path]
	return ClipLevels.of(stream)


## Sets how loud [param stream] plays from now until the game closes, which is how the mixer
## tries levels. A track already playing changes at once. Nothing is saved: the defaults
## are the table in [ClipLevels].
func set_clip_volume(stream: AudioStream, level: float) -> void:
	_levels[stream.resource_path] = clampf(level, 0.0, ClipLevels.MAX)
	if stream == _music:
		if _music_tweens[_current]:
			_music_tweens[_current].kill()
		_music_players[_current].volume_linear = get_clip_volume(stream)


## The track playing, or null.
func get_music() -> AudioStream:
	return _music


## Plays [param stream] once at its [method get_clip_volume], its pitch varied at random by
## up to [param pitch_jitter] (0.1 is ±10%). With every player busy, the oldest sound is
## cut off.
func play_sfx(stream: AudioStream, pitch_jitter := 0.0) -> void:
	var player := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_PLAYERS
	player.stream = stream
	player.volume_linear = get_clip_volume(stream)
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Sets [param bus]'s volume, from 0.0 (silent) to 1.0 (as mixed).
func set_volume(bus: Bus, linear: float) -> void:
	AudioServer.set_bus_volume_linear(_index(bus), linear)


## [param bus]'s volume, from 0.0 (silent) to 1.0 (as mixed).
func get_volume(bus: Bus) -> float:
	return AudioServer.get_bus_volume_linear(_index(bus))


# The cutoff moves in octaves, as the ear hears pitch, so it closes evenly.
func _set_muffle(amount: float) -> void:
	_muffle = amount
	var bus := _index(Bus.MUFFLE)
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	filter.cutoff_hz = exp(lerpf(log(OPEN_CUTOFF), log(MUFFLED_CUTOFF), amount))
	AudioServer.set_bus_volume_linear(bus, lerpf(1.0, MUFFLED_VOLUME, amount))


func _index(bus: Bus) -> int:
	return AudioServer.get_bus_index(BUS_NAMES[bus])


func _add_player(bus: Bus) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS_NAMES[bus]
	add_child(player)
	return player


func _fade(index: int, to: float, duration: float) -> Tween:
	# A newer fade replaces an older one on the same player, so a stale fade-out
	# can't stop a track that has started again.
	if _music_tweens[index]:
		_music_tweens[index].kill()
	var tween := create_tween()
	tween.tween_property(_music_players[index], "volume_linear", to, duration)
	_music_tweens[index] = tween
	return tween


func _fade_out(index: int, duration: float) -> void:
	_fade(index, 0.0, duration).tween_callback(_music_players[index].stop)
