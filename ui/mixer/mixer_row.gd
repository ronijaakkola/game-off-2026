class_name MixerRow
extends HBoxContainer
## One sound clip in the mixer: its name, a button to play it, and its level. A track plays
## as the music, a clip that loops plays until stopped (starting on the music's beat), and
## any other plays once.

signal changed

## The clip's path from the project root, and the clip.
var path := ""
var clip: AudioStream

var _track := false
var _looping := false
var _player: AudioStreamPlayer
var _start: Tween
var _was_playing := false


func _process(_delta: float) -> void:
	var playing := is_playing()
	if playing != _was_playing:
		_was_playing = playing
		(%PlayButton as Button).text = "Stop" if playing else "Play"


## Shows [param stream], found at [param clip_path], at its level now.
func setup(clip_path: String, stream: AudioStream) -> void:
	path = clip_path
	clip = stream
	_track = ClipFinder.is_track(stream)
	_looping = ClipFinder.loops(stream)
	(%NameLabel as Label).text = clip_path.get_file()
	(%NameLabel as Label).tooltip_text = clip_path
	(%KindLabel as Label).text = "track" if _track else "loop" if _looping else ""
	var level := %Level as LevelControl
	level.set_level(Audio.get_clip_volume(stream))
	level.changed.connect(_on_level_changed)
	(%PlayButton as Button).pressed.connect(_on_play_pressed)
	_show_mark()


func get_level() -> float:
	return (%Level as LevelControl).get_level()


## Whether it is not at the level the table gives it.
func is_edited() -> bool:
	return not is_equal_approx(get_level(), ClipLevels.of(clip))


## Whether the table has no entry for it, so it plays as recorded unless set here.
func is_unset() -> bool:
	return not ClipLevels.LEVELS.has(path)


func is_playing() -> bool:
	if _track:
		return Audio.get_music() == clip
	var waiting := _start != null and _start.is_valid() and _start.is_running()
	return waiting or (_player != null and _player.playing)


## Back to the level the table gives it.
func reset() -> void:
	(%Level as LevelControl).set_level(ClipLevels.of(clip))
	_apply(ClipLevels.of(clip))


## Stops it if it is playing on its own, as a loop does. A track is the music's to stop.
func stop() -> void:
	if _start:
		_start.kill()
	if _player:
		_player.stop()


func _on_level_changed(level: float) -> void:
	_apply(level)


func _apply(level: float) -> void:
	Audio.set_clip_volume(clip, level)
	if _player:
		_player.volume_linear = level
	_show_mark()
	changed.emit()


func _show_mark() -> void:
	var mark := %MarkLabel as Label
	if is_edited():
		mark.text = "edited"
	elif is_unset():
		mark.text = "unset"
	else:
		mark.text = ""


func _on_play_pressed() -> void:
	if _track:
		if is_playing():
			Audio.stop_music(0.3)
		else:
			Audio.play_music(clip, 0.3)
	elif _looping:
		if is_playing():
			stop()
		else:
			_play_loop()
	else:
		Audio.play_sfx(clip)


# A loop starts on the music's next beat, as the ringtone does in the game.
func _play_loop() -> void:
	if not _player:
		_player = AudioStreamPlayer.new()
		_player.stream = clip
		_player.bus = Audio.BUS_NAMES[Audio.Bus.SFX]
		add_child(_player)
	_player.volume_linear = get_level()
	var wait := Audio.seconds_to_beat()
	if wait <= 0.0:
		_player.play()
		return
	_start = create_tween()
	_start.tween_interval(wait)
	_start.tween_callback(_player.play)
