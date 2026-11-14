class_name CourseDrag
extends RefCounted
## A point in space the player put on the route with a right click and still holds the
## button on: it follows the pointer across the orbit plane every frame until the button
## comes up, so the player can steer the bus by hand. Where the bus reaches it, as when the
## pointer rests, it stops there; moving on again by [constant RESUME_DISTANCE] sets a new
## point to follow, which leaves at once while the drive is still warm from stopping.

## The plane the planets orbit on, where every stop is.
const ORBIT_PLANE := Plane(Vector3.UP, 0.0)
## How far the pointer moves from a point the bus rests at before a new one is set.
const RESUME_DISTANCE := 0.3
## How close the bus is to the point to have reached it.
const REACHED_DISTANCE := 0.2

var _bus: FrameshiftBus
var _camera: Camera3D
var _stop: RouteStop


func _init(bus: FrameshiftBus, camera: Camera3D) -> void:
	_bus = bus
	_camera = camera


## Where on the orbit plane [param screen_point] looks through [param camera], or null when
## it looks above the plane.
static func point_under(camera: Camera3D, screen_point: Vector2) -> Variant:
	return ORBIT_PLANE.intersects_ray(
		camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point)
	)


## Follows [param stop] while the right button stays down, if it is a point in space.
func start(stop: RouteStop) -> void:
	_stop = null if stop.planet else stop


## Moves the point being followed to under [param screen_point], once a frame. Lets go when
## the button comes up, or when the point leaves the route other than by the bus resting
## there.
func follow(screen_point: Vector2) -> void:
	if not _stop:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_stop = null
		return
	var hit: Variant = point_under(_camera, screen_point)
	if hit == null:
		return
	var at := hit as Vector3
	if _bus.get_route_stops().has(_stop):
		_stop.point = at
		return
	var resting := (
		_bus.state == FrameshiftBus.State.HOLDING
		and _bus.get_last_stop() == null
		and _bus.global_position.distance_to(_stop.point) < REACHED_DISTANCE
	)
	if not resting:
		_stop = null
	elif at.distance_to(_stop.point) > RESUME_DISTANCE:
		_stop = RouteStop.at_point(at)
		_bus.plot_course(_stop)
