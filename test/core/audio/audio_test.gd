extends GdUnitTestSuite

const AudioScript := preload("res://core/audio/audio.gd")
# Made here rather than loaded: core tests name no file outside core/, which outlives
# the sounds that ui/ and game/ replace on jam day.
var _music := _silence()
var _sfx := _silence()
var _other_sfx := _silence()
var _audio: AudioScript


func before_test() -> void:
	_audio = auto_free(AudioScript.new())
	add_child(_audio)


func test_same_track_keeps_playing() -> void:
	_audio.play_music(_music, 0.0)
	var first := _players_playing(_music)
	_audio.play_music(_music, 0.0)
	await await_idle_frame()
	assert_array(_players_playing(_music)).has_size(1).contains_exactly(first)


func test_a_new_sfx_plays_even_when_many_are_playing() -> void:
	for i: int in 20:
		_audio.play_sfx(_sfx)
	_audio.play_sfx(_other_sfx)
	assert_array(_players_playing(_other_sfx)).has_size(1)


# A second of silence. Each call makes a stream of its own, so tests tell them apart.
func _silence() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var data := PackedByteArray()
	data.resize(stream.mix_rate * 2)
	stream.data = data
	return stream


func _players_playing(stream: AudioStream) -> Array[AudioStreamPlayer]:
	var playing: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _audio.find_children("*", "AudioStreamPlayer", false, false):
		if player.playing and player.stream == stream:
			playing.append(player)
	return playing
