class_name SidePanel
extends MarginContainer
## A panel down the right side of the screen, anchored to its right edge, that slides in
## from past the edge over [member slide_in_seconds], so it can arrive with the camera, and
## back out, then hides. It starts hidden. The open planet's panel and the open bus's are
## ones.

const SLIDE_OUT_SECONDS := 0.2

## Seconds to slide in. It eases in and out, as the camera's blend does.
var slide_in_seconds := 0.7

# The one tween that slides the panel in and out.
var _slide: Tween


func _ready() -> void:
	hide()


## Shows the panel and slides it in, from past the right edge unless it is already showing.
func slide_in() -> void:
	if _slide:
		_slide.kill()
	if not visible:
		show()
		position.x = _off_right()
	_slide = create_tween()
	(
		_slide
		. tween_property(self, ^"position:x", _rest_x(), slide_in_seconds)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Slides out past the right edge, then hides.
func slide_out() -> void:
	if _slide:
		_slide.kill()
	_slide = create_tween()
	(
		_slide
		. tween_property(self, ^"position:x", _off_right(), SLIDE_OUT_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
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
