class_name MoneyEffect
extends RichTextEffect
## The [code][money][/code] tag in what a caller says: the words in the gold of the credits'
## dollar sign, bobbing gently a letter after another, with a glint running along them now
## and then. Under Reduce motion they are only gold.

## The gold of the credits' dollar sign.
const GOLD := Color(1, 0.831, 0.361)
## What the glint brightens a letter to, and how far, as a share of the way from the gold.
const GLINT := Color(1, 0.98, 0.86)
const GLINT_STRENGTH := 0.8
## Seconds between glints, letters the glint covers at once, and letters it runs a second.
const GLINT_PERIOD := 2.4
const GLINT_WIDTH := 2.5
const GLINT_SPEED := 18.0
## How far a letter bobs, in pixels, how fast, in radians a second, and how far behind the
## letter before it, in radians.
const BOB_PIXELS := 1.5
const BOB_SPEED := 5.0
const BOB_STEP := 0.6

## The tag's name, which a [RichTextEffect] reads from this member.
var bbcode := "money"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var color := GOLD
	if not Settings.reduce_motion:
		var index := float(char_fx.relative_index)
		var time := char_fx.elapsed_time
		char_fx.offset.y += sin(time * BOB_SPEED - index * BOB_STEP) * BOB_PIXELS
		# Where the glint is along the word, from before its first letter onward.
		var glint := fmod(time, GLINT_PERIOD) * GLINT_SPEED - GLINT_WIDTH
		var near := clampf(1.0 - absf(index - glint) / GLINT_WIDTH, 0.0, 1.0)
		color = GOLD.lerp(GLINT, near * near * GLINT_STRENGTH)
	char_fx.color = Color(color, char_fx.color.a)
	return true
