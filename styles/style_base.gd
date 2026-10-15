extends Node3D
## The style base: a rounded cube and a sphere under a shadowed sun. The camera circles
## them at [member orbit_speed] while the sun stays put, so every angle of the lighting,
## the shadow and the edges shows up in the rendering style under test.

## Degrees per second the camera orbits at. 0 holds it still, for a fixed comparison.
@export var orbit_speed := 20.0

@onready var _pivot: Node3D = %CameraPivot


func _process(delta: float) -> void:
	_pivot.rotation.y += deg_to_rad(orbit_speed) * delta
