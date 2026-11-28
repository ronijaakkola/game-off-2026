class_name StarLinks
extends Control
## The lines between the stars on the [StarChart]: one from each star system the
## bus has been to to the next, in the order they open, so the stars read as one line. Each
## stops short of both stars. They fade in over the last part of the pull back and out
## again as it closes. As the bus sets out for another star they fade out, since it flies
## to where that star's stargate is rather than along the link, and stay out until the
## chart has closed. The links from the star the bus is beside are brighter: the bus
## goes through the stargate one link at a time ([method StarMap.can_travel]).

## How far from each star's centre a link stops, in units.
const GAP := 10.0
## How far through the pull back the links start to show.
const SHOWS_FROM := 0.75
const WIDTH := 2.0
## Seconds they take to fade out as the bus sets out, and back in.
const FADE_SECONDS := 0.25
const COLOR := Color(1.0, 1.0, 1.0, 0.25)
const NEAR_COLOR := Color(1.0, 1.0, 1.0, 0.55)

@export var star_chart: StarChart
@export var star_map: StarMap

# Whether the bus has set out for another star on the chart that is open.
var _gone := false
# How much of them shows through that, from 0 to 1.
var _shown := 1.0


func _process(delta: float) -> void:
	if star_chart.is_travelling():
		_gone = true
	elif star_chart.get_progress() <= 0.0:
		_gone = false
	var fade := INF if Settings.reduce_motion else delta / FADE_SECONDS
	_shown = move_toward(_shown, 0.0 if _gone else 1.0, fade)
	var shown := star_chart.get_progress() > SHOWS_FROM and _shown > 0.0
	if shown or visible:
		visible = shown
		queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var strength := smoothstep(SHOWS_FROM, 1.0, star_chart.get_progress()) * _shown
	var systems := star_map.get_visited()
	var current := star_map.get_current()
	for i: int in systems.size() - 1:
		var from := systems[i].global_position
		var to := systems[i + 1].global_position
		var along := (to - from).normalized()
		var near := systems[i] == current or systems[i + 1] == current
		var color := NEAR_COLOR if near else COLOR
		draw_line(
			camera.unproject_position(from + along * GAP),
			camera.unproject_position(to - along * GAP),
			Color(color, color.a * strength),
			WIDTH,
			true
		)
