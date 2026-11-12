class_name PassengerPhoto
extends Control
## A passenger's portrait as a small photo: a thin white frame tilted a little at random,
## over a blurred background in their [Race]'s backdrop colour. It takes its portrait from
## [member studio] while it is in the tree and gives it back when it leaves, so a freed
## photo frees its slot. When the studio is full it waits for the next free slot. Without
## a studio or a passenger the frame stays empty. While the passenger rides, it shows on
## the portrait every frame whether they are asleep, how angry or content their mood makes
## them, what they are eating or drinking, and the push they feel on the bus.
## The framed photo is drawn at [constant FRAME_SIZE] and scaled to the photo's minimum
## size, so a scene can make it smaller. Their type's badges ([member PassengerType.badges])
## sit in a row from the photo's top left corner, a little past it, tilted with it, and the
## pointer over one shows a tooltip with the type's name and description. A flag badge
## joins them while a quest is about the passenger, its tooltip saying what the quest
## asks. With
## [member flat] on, it is a flat square with rounded corners instead, as big as the minimum
## size, with no frame and no tilt.

const BADGE := preload("res://game/passengers/photo_badge.tscn")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const FLAG := preload("res://shared/icons/flag.svg")
## A badge's size, the gap between its rim and its icon, and how far the badges reach past
## the photo's top left corner, in pixels, on a photo [constant BADGE_PHOTO_SIZE] wide.
## On a bigger photo they all grow, [constant BADGE_GROWTH] as fast as the photo.
const BADGE_SIZE := 15.0
const BADGE_PAD := 3.0
const BADGE_OVERHANG := 4.0
const BADGE_PHOTO_SIZE := 32.0
const BADGE_GROWTH := 0.5
## The framed photo's size as laid out in its scene, in pixels.
const FRAME_SIZE := 50.0
## The flat photo's corner radius, in pixels.
const FLAT_RADIUS := 8
## The photo's tilt, in degrees either way.
const TILT_MIN := 0.5
const TILT_MAX := 2.0
## How angry each mood looks on the portrait; the others look calm.
const MOOD_ANGER: Dictionary[Passenger.Mood, float] = {
	Passenger.Mood.ANNOYED: 0.5,
	Passenger.Mood.FURIOUS: 1.0,
}

## Whether the photo is a flat rounded square rather than a tilted, framed print. Set it
## in the scene that uses the photo; it applies once, when the photo is ready.
@export var flat := false
## Whether the passenger rides the bus, so their portrait leans with its pushes. Their
## card sets it; while they wait at a planet it stays off, and so does the portrait.
var riding := false:
	set(value):
		riding = value
		set_process(value)

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
# The passenger's quest line the badges were last made for.
var _quest_line := ""


func _ready() -> void:
	set_process(riding)
	if flat:
		_flatten()
	else:
		var tilt := randf_range(TILT_MIN, TILT_MAX) * (1.0 if randf() < 0.5 else -1.0)
		var frame := %Frame as Control
		frame.rotation = deg_to_rad(tilt)
		# Scaled about its centre, which is also where it tilts.
		frame.scale = Vector2.ONE * custom_minimum_size.x / FRAME_SIZE
		frame.position = (custom_minimum_size - Vector2.ONE * FRAME_SIZE) * 0.5
	_backdrop().set_shader_parameter(&"seed", randf() * 100.0)
	_show()


func _process(_delta: float) -> void:
	if passenger and passenger.quest_line != _quest_line:
		_show_badges()
	var portrait := studio.get_portrait(_photo) if studio and _photo else null
	if not portrait:
		return
	portrait.asleep = passenger.asleep
	portrait.anger = MOOD_ANGER.get(passenger.get_mood(), 0.0)
	portrait.content = passenger.get_mood() == Passenger.Mood.HAPPY
	portrait.action = passenger.action
	portrait.felt_acceleration = studio.felt_acceleration if riding else Vector2.ZERO


func _exit_tree() -> void:
	_give_back()


## The photo's tile of the studio's render, or null while it has none.
func get_photo() -> Texture2D:
	return _photo


func _show() -> void:
	_show_badges()
	if not passenger:
		return
	_backdrop().set_shader_parameter(&"backdrop_color", Race.BACKDROP_COLORS[passenger.race])
	if studio and not _photo and is_inside_tree():
		_photo = studio.add(passenger.look)
		if not _photo and not studio.slot_freed.is_connected(_show):
			studio.slot_freed.connect(_show, CONNECT_ONE_SHOT)
	(%Photo as TextureRect).texture = _photo


# One badge for each of the passenger's type's, then a flag while a quest is about them,
# or none without a passenger.
func _show_badges() -> void:
	var badges := %Badges as Control
	for badge: Node in badges.get_children():
		badges.remove_child(badge)
		badge.queue_free()
	_quest_line = passenger.quest_line if passenger else ""
	if not passenger:
		return
	var type := passenger.type
	for texture: Texture2D in type.badges:
		badges.add_child(_make_badge(texture, type.display_name, type.description))
	if not _quest_line.is_empty():
		badges.add_child(_make_badge(FLAG, "Quest", _quest_line))
	var grow := _badge_growth()
	badges.size = badges.get_combined_minimum_size()
	badges.position = -Vector2.ONE * roundf(BADGE_OVERHANG * grow)
	# They turn about the photo's centre, as the frame does, so they stay on its corner.
	badges.pivot_offset = custom_minimum_size * 0.5 - badges.position
	badges.rotation = (%Frame as Control).rotation


# A badge showing [param texture], with a tooltip of [param title] and [param sentence]
# when there is a sentence.
func _make_badge(texture: Texture2D, title: String, sentence: String) -> PhotoBadge:
	var grow := _badge_growth()
	var badge := BADGE.instantiate() as PhotoBadge
	# Whole pixels each side, so the icon sits dead centre.
	badge.show_icon(texture, roundf(BADGE_SIZE * grow), roundf(BADGE_PAD * grow))
	if not sentence.is_empty():
		# It takes the pointer for its tooltip and passes it on, so the row or card
		# under it still sees the pointer and its clicks.
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		var tooltip := TOOLTIP.instantiate() as Tooltip
		tooltip.target = badge
		tooltip.title = title
		tooltip.sentence = sentence
		badge.add_child(tooltip)
	return badge


# How much bigger the badges are than on a photo BADGE_PHOTO_SIZE wide.
func _badge_growth() -> float:
	return lerpf(1.0, custom_minimum_size.x / BADGE_PHOTO_SIZE, BADGE_GROWTH)


func _give_back() -> void:
	if studio and studio.slot_freed.is_connected(_show):
		studio.slot_freed.disconnect(_show)
	if _photo and studio:
		studio.remove(_photo)
	_photo = null
	if is_node_ready():
		(%Photo as TextureRect).texture = null


# The frame becomes a rounded mask as big as the photo, and the backdrop and portrait fill
# it, clipped to its corners.
func _flatten() -> void:
	var frame := %Frame as Control
	var mask := StyleBoxFlat.new()
	mask.set_corner_radius_all(FLAT_RADIUS)
	frame.add_theme_stylebox_override(&"panel", mask)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.position = Vector2.ZERO
	frame.size = custom_minimum_size
	for child: Control in [%Backdrop, %Photo]:
		child.position = Vector2.ZERO
		child.size = custom_minimum_size


func _backdrop() -> ShaderMaterial:
	return (%Backdrop as ColorRect).material as ShaderMaterial
