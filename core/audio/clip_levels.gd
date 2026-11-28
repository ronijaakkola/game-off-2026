class_name ClipLevels
extends RefCounted
## How loud each sound clip plays by default, as a multiple of how it was recorded: 1 is as
## recorded, below 1 is quieter and above 1 louder. A clip with no entry plays at 1. The
## mixer (the debug panel's Mixer) lists every clip and its Copy button puts this table on
## the clipboard, to paste over [constant LEVELS]. The alien voices' clips have no entry: a
## race's [member Voice.volume] sets how loud its voice is.
## [method Audio.get_clip_volume] reads it; code never reads it directly.

## Level by the clip's path from the project root, in path order. It is a table of data, not
## a use of the clips: the clips stay in the folder of the feature that plays them.
const LEVELS: Dictionary[String, float] = {
	"game/bus/dock_bell.ogg": 0.5,
	"game/bus/flying.ogg": 0.7,
	"game/solar_system/fuel.ogg": 0.35,
	"game/solar_system/ringtone.ogg": 0.15,
	"ui/audio/bgm1.ogg": 0.7,
	"ui/audio/bgm2.ogg": 0.7,
	"ui/audio/key_click.ogg": 1.0,
	"ui/audio/menu_music.ogg": 0.7,
	"ui/audio/ui_click.ogg": 1.0,
}
## The level of a clip with no entry.
const DEFAULT := 1.0
## The most a level can be: twice as loud as recorded.
const MAX := 2.0


## The default level of [param stream], by its path: [constant DEFAULT] with no entry, or
## for a stream that isn't a file.
static func of(stream: AudioStream) -> float:
	if not stream:
		return DEFAULT
	return LEVELS.get(stream.resource_path.trim_prefix("res://"), DEFAULT)
