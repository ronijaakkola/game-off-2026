class_name ClipFinder
extends RefCounted
## Finds the sound clips in the project for the mixer, so a clip added later is in it with no
## code to change. The alien voices' clips are left out: the mixer sets a race's voice
## level, not each clip's.

const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
## Folders whose clips are not the game's sounds, as paths from the project root.
const SKIPPED: Array[String] = [
	"addons/", "build/", "docs/", "test/", "tools/", "game/transmissions/voice/"
]
## A clip at least this long, in seconds, is a music track, not a sound effect.
const TRACK_SECONDS := 30.0


## Every clip's path from the project root, in order.
static func find() -> PackedStringArray:
	var found := PackedStringArray()
	_scan("", found)
	found.sort()
	return found


## Whether [param stream] is a music track: long enough to be one.
static func is_track(stream: AudioStream) -> bool:
	return stream.get_length() >= TRACK_SECONDS


## Whether [param stream] loops by its import, so playing it has to be stopped.
static func loops(stream: AudioStream) -> bool:
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false


static func _scan(folder: String, found: PackedStringArray) -> void:
	for entry: String in ResourceLoader.list_directory("res://" + folder):
		var path := folder + entry
		if entry.begins_with("."):
			continue
		if entry.ends_with("/"):
			if not SKIPPED.has(path):
				_scan(path, found)
		elif entry.get_extension() in EXTENSIONS:
			found.append(path)
