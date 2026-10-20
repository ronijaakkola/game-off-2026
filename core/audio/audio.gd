extends Node
## Music and sound effects. Music crossfades between two players, one track at a time.
## Sound effects take turns on a pool of players. It processes always, so music keeps
## playing while the game is paused. It owns the mixer's buses: code names a bus as an
## [enum Bus], never by its name.

## The buses in core/audio/default_bus_layout.tres.
enum Bus { MASTER, MUSIC, SFX }

const SFX_PLAYERS := 8
## Each [enum Bus]'s name in default_bus_layout.tres. Set an AudioStreamPlayer's bus from it:
## [code]player.bus = Audio.BUS_NAMES[Audio.Bus.SFX][/code].
const BUS_NAMES: Dictionary[Bus, StringName] = {
	Bus.MASTER: &"Master",
	Bus.MUSIC: &"Music",
	Bus.SFX: &"SFX",
}

var _music_players: Array[AudioStreamPlayer] = []
var _music_tweens: Array[Tween] = [null, null]
var _current := 0
var _music: AudioStream
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for i: int in 2:
		_music_players.append(_add_player(Bus.MUSIC))
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
	_fade(_current, 1.0, fade)


## Fades the music out over [param fade] seconds.
func stop_music(fade := 1.0) -> void:
	_music = null
	_fade_out(_current, fade)


## Plays [param stream] once, its pitch varied at random by up to [param pitch_jitter]
## (0.1 is ±10%). With every player busy, the oldest sound is cut off.
func play_sfx(stream: AudioStream, pitch_jitter := 0.0) -> void:
	var player := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_PLAYERS
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Sets [param bus]'s volume, from 0.0 (silent) to 1.0 (as mixed).
func set_volume(bus: Bus, linear: float) -> void:
	AudioServer.set_bus_volume_linear(_index(bus), linear)


## [param bus]'s volume, from 0.0 (silent) to 1.0 (as mixed).
func get_volume(bus: Bus) -> float:
	return AudioServer.get_bus_volume_linear(_index(bus))


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
