class_name TalkPace
extends RefCounted
## How fast a caller's text types out, as a speaking pace: how long each letter waits for the
## next. The [TransmissionPanel] types at it, and the [VoiceSpeaker] reads ahead with it to
## fit a blip to its word.

## Seconds after each letter, after a space, after a comma, colon or dash, and after a full
## stop, question or exclamation mark.
const LETTER_SECONDS := 0.04
const SPACE_SECONDS := 0.07
const COMMA_SECONDS := 0.25
const STOP_SECONDS := 0.5


## How long the caller waits after saying [param letter] before the next, before any
## variation.
static func wait_after(letter: String) -> float:
	if letter in [".", "!", "?"]:
		return STOP_SECONDS
	if letter in [",", ";", ":", "—"]:
		return COMMA_SECONDS
	if letter == " ":
		return SPACE_SECONDS
	return LETTER_SECONDS
