extends GdUnitTestSuite

const AudioScript := preload("res://core/audio/audio.gd")
const MUSIC := preload("res://ui/audio/bg.ogg")
const SFX := preload("res://ui/audio/ui_click.ogg")
const OTHER_SFX := preload("res://game/bus/dock_bell.ogg")
const RINGTONE := preload("res://game/solar_system/ringtone.ogg")

var _audio: AudioScript


func before_test() -> void:
	_audio = auto_free(AudioScript.new())
	add_child(_audio)


func test_same_track_keeps_playing() -> void:
	_audio.play_music(MUSIC, 0.0)
	var first := _players_playing(MUSIC)
	_audio.play_music(MUSIC, 0.0)
	await await_idle_frame()
	assert_array(_players_playing(MUSIC)).has_size(1).contains_exactly(first)


func test_a_new_sfx_plays_even_when_many_are_playing() -> void:
	for i: int in 20:
		_audio.play_sfx(SFX)
	_audio.play_sfx(OTHER_SFX)
	assert_array(_players_playing(OTHER_SFX)).has_size(1)


func _players_playing(stream: AudioStream) -> Array[AudioStreamPlayer]:
	var playing: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _audio.find_children("*", "AudioStreamPlayer", false, false):
		if player.playing and player.stream == stream:
			playing.append(player)
	return playing


# A name that isn't in the layout sends a player to Master and makes set_volume do nothing,
# both silently.
func test_every_bus_is_in_the_bus_layout() -> void:
	for bus: AudioScript.Bus in AudioScript.Bus.values():
		var bus_name: StringName = AudioScript.BUS_NAMES.get(bus, &"")
		var message := "%s has no bus in default_bus_layout.tres" % AudioScript.Bus.find_key(bus)
		(
			assert_int(AudioServer.get_bus_index(bus_name))
			. override_failure_message(message)
			. is_not_equal(-1)
		)


func test_set_volume_reaches_the_bus() -> void:
	var before := _audio.get_volume(AudioScript.Bus.MUSIC)
	_audio.set_volume(AudioScript.Bus.MUSIC, 0.3)
	var music := AudioServer.get_bus_index(&"Music")
	assert_float(AudioServer.get_bus_volume_linear(music)).is_equal_approx(0.3, 0.001)
	_audio.set_volume(AudioScript.Bus.MUSIC, before)


func test_a_sound_effect_plays_at_its_clip_level() -> void:
	_audio.play_sfx(RINGTONE)
	var playing := _players_playing(RINGTONE)
	assert_array(playing).has_size(1)
	assert_float(playing[0].volume_linear).is_equal_approx(ClipLevels.of(RINGTONE), 0.001)


func test_a_level_set_for_the_run_wins_over_the_table() -> void:
	_audio.set_clip_volume(RINGTONE, 1.7)
	assert_float(_audio.get_clip_volume(RINGTONE)).is_equal_approx(1.7, 0.001)
	_audio.set_clip_volume(RINGTONE, 9.0)
	assert_float(_audio.get_clip_volume(RINGTONE)).is_equal_approx(ClipLevels.MAX, 0.001)
	_audio.play_sfx(RINGTONE)
	assert_float(_players_playing(RINGTONE)[0].volume_linear).is_equal_approx(ClipLevels.MAX, 0.001)


func test_a_level_set_while_a_track_plays_changes_it_at_once() -> void:
	_audio.play_music(MUSIC, 0.0)
	await await_idle_frame()
	_audio.set_clip_volume(MUSIC, 0.4)
	assert_float(_players_playing(MUSIC)[0].volume_linear).is_equal_approx(0.4, 0.001)
	assert_object(_audio.get_music()).is_same(MUSIC)
