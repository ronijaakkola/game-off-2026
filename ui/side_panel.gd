class_name SidePanel
extends MarginContainer
## A panel down the right side of the screen, anchored to its right edge, that slides in
## from past the edge over [member slide_seconds], so it can arrive with the camera, and
## back out in the same time, as the camera pulls back, then hides. It starts hidden. The
## open planet's panel and the open bus's are ones. Under Reduce motion it fades in and out
## in place instead.

## Seconds to slide out when another panel takes its place.
const SWAP_SECONDS := 0.2
## Seconds to fade in or out under Reduce motion.
const FADE_SECONDS := 0.2

## Seconds to slide in or out. It eases in and out, as the camera's blend does.
var slide_seconds := 0.7

# The one tween that slides the panel in and out.
var _slide: Tween


func _ready() -> void:
	hide()


## Shows the panel and slides it in, from past the right edge unless it is already showing.
func slide_in() -> void:
	if _slide:
		_slide.kill()
	var still := Settings.reduce_motion
	if not visible:
		show()
		position.x = _off_right()
		modulate.a = 0.0 if still else 1.0
	_slide = create_tween()
	if still:
		position.x = _rest_x()
		_slide.tween_property(self, ^"modulate:a", 1.0, FADE_SECONDS)
		return
	modulate.a = 1.0
	(
		_slide
		. tween_property(self, ^"position:x", _rest_x(), slide_seconds)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Slides out past the right edge, then hides. With [param swapped], another panel is
## sliding in over it, so it leaves fast instead of with the camera.
func slide_out(swapped := false) -> void:
	if _slide:
		_slide.kill()
	_slide = create_tween()
	if Settings.reduce_motion:
		_slide.tween_property(self, ^"modulate:a", 0.0, FADE_SECONDS)
	else:
		(
			_slide
			. tween_property(
				self, ^"position:x", _off_right(), SWAP_SECONDS if swapped else slide_seconds
			)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT if swapped else Tween.EASE_IN_OUT)
		)
	_slide.tween_callback(hide)


## How wide the panel is, margins included, so the parent can keep what it frames clear of
## it.
func get_width() -> float:
	return get_combined_minimum_size().x


# Where the anchors put the panel, flush with the right edge.
func _rest_x() -> float:
	return get_parent_area_size().x - size.x


func _off_right() -> float:
	return get_parent_area_size().x
