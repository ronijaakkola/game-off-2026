class_name SystemMusic
extends Node
## Plays the music of the star system the bus works in ([member StarSystem.music]): as the
## game scene starts, and again as the bus crosses into another system, where the track
## playing fades out as the new one fades in.

## Seconds one track fades out and the next in over.
const FADE_SECONDS := 2.0

@export var star_map: StarMap


func _ready() -> void:
	star_map.changed.connect(_play)
	_play()


# The map changes without the bus moving too, and asking for the track already playing
# does nothing.
func _play() -> void:
	var music := star_map.get_current().music
	if music:
		Audio.play_music(music, FADE_SECONDS)
