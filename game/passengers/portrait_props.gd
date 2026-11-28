class_name PortraitProps
extends RefCounted
## What an [AlienPortrait] wears or carries besides its head: the parts of its model named
## for it, such as a bow tie ([constant TIE]) or a briefcase ([constant BRIEFCASE]). A part
## shows only while it is worn ([method wear]). Worn while the portrait shows, as The Boss's
## are when the player fetches them, it grows in from nothing past its size and settles
## rather than snapping on; taken off, it shrinks away. Under Reduce motion it is there, or
## gone, at once. A model with no such part shows nothing for it.

## The ends of the names of the model's parts, such as MoundTie and BossBriefcase.
const TIE := "Tie"
const BRIEFCASE := "Briefcase"
const KINDS: Array[String] = [TIE, BRIEFCASE]
## Growing in: seconds, with a slight overshoot. Shrinking away: seconds.
const APPEAR_SECONDS := 0.45
const LEAVE_SECONDS := 0.15
## The size a part grows from and shrinks to: a part at no size has no transform to draw.
const GONE := 0.01

var _worn: Dictionary[String, bool] = {}
var _parts: Dictionary[String, Array] = {}
var _tweens: Dictionary[Node3D, Tween] = {}


## Takes [param part] of the model if it is something worn or carried, and shows it only
## while it is. False for any other part.
func take(part: Node3D) -> bool:
	for kind: String in KINDS:
		if part.name.ends_with(kind):
			_parts.get_or_add(kind, []).append(part)
			part.visible = is_worn(kind)
			return true
	return false


## Whether [param kind] is worn.
func is_worn(kind: String) -> bool:
	return _worn.get(kind, false)


## Dresses the portrait as [param type] does, or in nothing for no type.
func dress(type: PassengerType, animated := false) -> void:
	wear(TIE, type != null and type.wears_bow_tie, animated)
	wear(BRIEFCASE, type != null and type.carries_briefcase, animated)


## Puts [param kind] on, or takes it off: [param animated], it grows in or shrinks away.
func wear(kind: String, worn: bool, animated := false) -> void:
	if worn == is_worn(kind):
		return
	_worn[kind] = worn
	for part: Node3D in _parts.get(kind, []):
		if _tweens.has(part):
			_tweens[part].kill()
		if not animated or Settings.reduce_motion or not part.is_inside_tree():
			part.scale = Vector3.ONE
			part.visible = worn
			continue
		var tween := part.create_tween()
		_tweens[part] = tween
		if worn:
			part.scale = Vector3.ONE * GONE
			part.visible = true
			(
				tween
				. tween_property(part, ^"scale", Vector3.ONE, APPEAR_SECONDS)
				. set_trans(Tween.TRANS_BACK)
				. set_ease(Tween.EASE_OUT)
			)
		else:
			(
				tween
				. tween_property(part, ^"scale", Vector3.ONE * GONE, LEAVE_SECONDS)
				. set_trans(Tween.TRANS_CUBIC)
				. set_ease(Tween.EASE_IN)
			)
			tween.tween_callback(part.hide)
