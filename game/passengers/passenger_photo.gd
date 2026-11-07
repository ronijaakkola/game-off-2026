class_name PassengerPhoto
extends Control
## A passenger's portrait as a small photo: a thin white frame tilted a little at random,
## over a blurred background in the colours of the planet they boarded at (or, when that
## isn't known, the one they are going to). It takes its portrait from [member studio]
## while it is in the tree and gives it back when it leaves, so a freed photo frees its
## slot. When the studio is full it waits for the next free slot. Without a studio or a
## passenger the frame stays empty. Every frame it shows on the portrait whether the
## passenger is asleep, and, while they ride, the push they feel on the bus.

## The photo's tilt, in degrees either way.
const TILT_MIN := 0.5
const TILT_MAX := 2.0

## Whether the passenger rides the bus, so their portrait leans with its pushes. Their
## card sets it; while they wait at a planet it stays off.
var riding := false

## Where the portrait is rendered.
var studio: PortraitStudio:
	set(value):
		_give_back()
		studio = value
		if is_node_ready():
			_show()
var passenger: Passenger:
	set(value):
		_give_back()
		passenger = value
		if is_node_ready():
			_show()

# The tile of the studio's render this photo shows, or null.
var _photo: AtlasTexture


func _ready() -> void:
	var tilt := randf_range(TILT_MIN, TILT_MAX) * (1.0 if randf() < 0.5 else -1.0)
	(%Frame as Control).rotation = deg_to_rad(tilt)
	_backdrop().set_shader_parameter(&"seed", randf() * 100.0)
	_show()


func _process(_delta: float) -> void:
	var portrait := studio.get_portrait(_photo) if studio and _photo else null
	if not portrait:
		return
	portrait.asleep = passenger.asleep
	portrait.felt_acceleration = studio.felt_acceleration if riding else Vector2.ZERO


func _exit_tree() -> void:
	_give_back()


## The photo's tile of the studio's render, or null while it has none.
func get_photo() -> Texture2D:
	return _photo


func _show() -> void:
	if not passenger:
		return
	var home := passenger.origin if passenger.origin else passenger.destination
	if home:
		_backdrop().set_shader_parameter(&"planet_color", home.icon_color)
	if studio and not _photo and is_inside_tree():
		_photo = studio.add(passenger.look)
		if not _photo and not studio.slot_freed.is_connected(_show):
			studio.slot_freed.connect(_show, CONNECT_ONE_SHOT)
	(%Photo as TextureRect).texture = _photo


func _give_back() -> void:
	if studio and studio.slot_freed.is_connected(_show):
		studio.slot_freed.disconnect(_show)
	if _photo and studio:
		studio.remove(_photo)
	_photo = null
	if is_node_ready():
		(%Photo as TextureRect).texture = null


func _backdrop() -> ShaderMaterial:
	return (%Backdrop as ColorRect).material as ShaderMaterial
