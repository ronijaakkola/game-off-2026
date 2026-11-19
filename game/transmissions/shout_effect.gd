class_name ShoutEffect
extends RichTextEffect
## The [code][shout][/code] tag in what a caller says: the words shake, each letter jumping
## about on its own [constant JUMPS] times a second. Under Reduce motion they hold still.

## How far a letter jumps each way, in pixels, and how often a second.
const PIXELS := 1.2
const JUMPS := 18.0

## The tag's name, which a [RichTextEffect] reads from this member.
var bbcode := "shout"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if Settings.reduce_motion:
		return true
	var jump := floorf(char_fx.elapsed_time * JUMPS)
	var index := float(char_fx.relative_index)
	char_fx.offset += Vector2(_noise(index, jump), _noise(index + 0.5, jump + 17.0)) * PIXELS
	return true


# A repeatable value from -1 to 1 for [param a] and [param b].
func _noise(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0) * 2.0 - 1.0
