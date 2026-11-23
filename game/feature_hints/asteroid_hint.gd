extends Control
## Offers the asteroid field feature hint the first time the bus flies into the rocks: on
## a spot round the bus on screen, which follows it, so the card points at the bus where
## the rocks slowed it.

## The spot's size on screen, in pixels: about the bus at the map's usual zoom.
const SPOT := Vector2(64.0, 64.0)
## After the camera and the bus have moved each frame, as the map's other labels.
const PROCESS_PRIORITY := 302

@export var hints: FeatureHints
@export var field: AsteroidField
@export var bus: FrameshiftBus


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SPOT
	field.entered_rocks.connect(_on_entered_rocks)


func _process(_delta: float) -> void:
	_follow()


func _on_entered_rocks() -> void:
	_follow()
	if hints.offer(&"asteroid_field", self):
		field.entered_rocks.disconnect(_on_entered_rocks)
		set_process(false)


# Centres the spot on the bus on screen.
func _follow() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		position = camera.unproject_position(bus.global_position) - SPOT / 2.0
