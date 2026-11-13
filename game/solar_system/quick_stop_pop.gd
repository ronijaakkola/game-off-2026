class_name QuickStopPop
extends Control
## "Quick stop!" over the bus as it leaves a planet with its drive still warm. It starts
## just above where the bus left from and rises [constant RISE_PIXELS] while it fades out,
## over [constant SECONDS]. Under Reduce motion it only fades. A new quick stop starts it
## again. It places itself after the camera has moved each frame.

## Seconds from showing to gone.
const SECONDS := 1.2
## Pixels it rises on screen over that time.
const RISE_PIXELS := 36.0
## Pixels between the bus on screen and its lower edge as it starts.
const GAP_PIXELS := 18.0
## The process priority Phantom Camera's host sets on itself to move the camera.
const CAMERA_HOST_PRIORITY := 300

## The bus whose quick stops it shows.
@export var bus: FrameshiftBus:
	set(value):
		if bus and bus.left_warm.is_connected(show_pop):
			bus.left_warm.disconnect(show_pop)
		bus = value
		if bus:
			bus.left_warm.connect(show_pop)
## The camera the bus is seen through.
@export var camera: Camera3D

# How far through its rise and fade it is, from 0 to 1.
var _age := 1.0
# Where the bus left from: it stays there as the bus flies off.
var _from := Vector3.ZERO
var _tween: Tween


func _ready() -> void:
	process_priority = CAMERA_HOST_PRIORITY + 1
	(%Label as Control).visible = false


## Shows it over where the bus is now, from the start.
func show_pop() -> void:
	if not bus:
		return
	_from = bus.global_position
	if _tween:
		_tween.kill()
	_age = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "_age", 1.0, SECONDS)


func _process(_delta: float) -> void:
	var label := %Label as Label
	var shown := _age < 1.0 and camera != null and not camera.is_position_behind(_from)
	label.visible = shown
	if not shown:
		return
	var rise := 0.0 if Settings.reduce_motion else RISE_PIXELS * ease(_age, 0.5)
	var at := camera.unproject_position(_from)
	label.size = label.get_combined_minimum_size()
	label.position = (at - Vector2(label.size.x * 0.5, label.size.y + GAP_PIXELS + rise)).round()
	# Holds for the first third, then fades.
	label.modulate.a = 1.0 - clampf((_age - 0.33) / 0.67, 0.0, 1.0)
