class_name PortraitStudio
extends SubViewport
## Renders every passenger portrait on screen in one pass: each [AlienPortrait] stands in
## its own slot of a row under one orthographic camera, and a card shows its slot's tile
## of the rendered texture. The photo is a close-up of the head, so the bust reaches down
## past its tile; with the slots in one row, that part falls outside the render rather
## than in a neighbour's tile. One pass for all of them is cheaper on the web than a viewport
## per card. It renders only while it holds a portrait.
## A photo borrows a portrait with [method lend], and the studio takes it back when the
## photo leaves the tree, so no slot stays taken by a photo that is gone. When every slot
## is taken, the photo waits its turn for the next one to free.

const PORTRAIT := preload("res://game/passengers/alien_portrait.tscn")
const SLOTS := 12
## Pixels per tile: about twice the size a card shows it at, so it stays sharp when the
## UI scales up in fullscreen.
const TILE := 96
## Pixels between tiles, so a bust reaching past its tile never shows in its neighbour's.
const GUTTER := 32
## Metres per tile in the 3D scene, square.
const SLOT := 1.0
## Each head is scaled to fill this much of its tile's height, or its width when that is
## the tighter fit, with this much room above it.
const FILL_HEIGHT := 0.8
const FILL_WIDTH := 1.0
const HEADROOM := 0.06
## Only this much of a tall head, from the top down, is fitted to the tile, so a head that
## is the whole body, such as the Bean's, is still a close-up.
const MAX_HEAD := 0.5
## How far below the tile's bottom a short bust's cut base sits, so it never floats.
const SINK := 0.06

## The push felt on the bus, for the portraits of passengers riding it, as
## [member AlienPortrait.felt_acceleration]: +x toward the passenger's right, +y forward.
## The scene that holds the bus sets it every frame.
var felt_acceleration := Vector2.ZERO
## How hard the passengers riding the bus sweat, as [member AlienPortrait.sweat]: above 0
## while the bus is past its comfortable temperature, 1 as it overheats. The scene that
## holds the bus sets it every frame.
var sweat := 0.0

# The portrait in each slot, or null.
var _slots: Array[AlienPortrait] = []
var _photos: Dictionary[AtlasTexture, AlienPortrait] = {}
# The photo each holder borrowed, and what it hands the photo to.
var _lent: Dictionary[Node, AtlasTexture] = {}
var _shown: Dictionary[Node, Callable] = {}
# Who waits for a free slot, first in line first, and the look and type they asked for.
var _waiting: Array[Node] = []
var _asked: Dictionary[Node, Array] = {}
# The materials no portrait draws until a passenger sweats or is angry: the drops' and the
# anger mark's. Kept here from the start, so the loading screen draws them first
# ([MaterialWarmUp]) and their shaders are compiled by then.
var _late_materials: Array[Material] = []


func _ready() -> void:
	size = Vector2i(SLOTS * _pitch(), _pitch())
	(%Camera as Camera3D).size = _pitch() * SLOT / TILE
	_slots.resize(SLOTS)
	_late_materials = [PortraitSweat.get_material(), AngerMark.make_material()]
	_update_rendering()


## Lends [param holder] a portrait of [param look], dressed as [param type], taking back the
## one it holds. [param shown] gets the photo of it, an [AtlasTexture], to show: now, or
## once a slot frees when every one is taken; a holder already waiting keeps its place in
## line. It gets null when the studio takes the photo back, on [method take_back] or as the
## holder leaves the tree. A holder out of the tree gets nothing.
func lend(holder: Node, look: AlienLook, type: PassengerType, shown: Callable) -> void:
	if _waiting.has(holder):
		_asked[holder] = [look, type]
		_shown[holder] = shown
		return
	take_back(holder)
	if not holder.is_inside_tree():
		return
	_shown[holder] = shown
	holder.tree_exiting.connect(take_back.bind(holder), CONNECT_ONE_SHOT)
	var photo := _add(look, type)
	if not photo:
		_waiting.append(holder)
		_asked[holder] = [look, type]
		return
	_lent[holder] = photo
	shown.call(photo)


## Takes back the portrait [param holder] borrowed, freeing its slot, or its place in line.
## Nothing happens when it has neither.
func take_back(holder: Node) -> void:
	if not _shown.has(holder):
		return
	var shown: Callable = _shown[holder]
	_shown.erase(holder)
	var leave := take_back.bind(holder)
	if holder.tree_exiting.is_connected(leave):
		holder.tree_exiting.disconnect(leave)
	_waiting.erase(holder)
	_asked.erase(holder)
	if not _lent.has(holder):
		return
	_remove(_lent[holder])
	_lent.erase(holder)
	shown.call(null)
	_serve_next()


## The portrait behind the photo [param holder] borrowed, or null while it has none.
func get_lent_portrait(holder: Node) -> AlienPortrait:
	return _photos.get(_lent.get(holder))


# The first in line gets the slot just freed.
func _serve_next() -> void:
	if _waiting.is_empty():
		return
	var holder: Node = _waiting.pop_front()
	var asked: Array = _asked[holder]
	_asked.erase(holder)
	var photo := _add(asked[0] as AlienLook, asked[1] as PassengerType)
	_lent[holder] = photo
	(_shown[holder] as Callable).call(photo)


# Puts a portrait of [param look], dressed as [param type], in a free slot and returns the
# photo of it to show, or null when every slot is taken.
func _add(look: AlienLook, type: PassengerType) -> AtlasTexture:
	var slot := _slots.find(null)
	if slot < 0:
		return null
	var portrait := new_portrait(look, type)
	%Portraits.add_child(portrait)
	var pitch := _pitch() * SLOT / TILE
	frame(portrait)
	portrait.position.x += (slot - (SLOTS - 1) / 2.0) * pitch
	_slots[slot] = portrait
	var photo := AtlasTexture.new()
	photo.atlas = get_texture()
	photo.region = Rect2(slot * _pitch() + GUTTER / 2.0, GUTTER / 2.0, TILE, TILE)
	_photos[photo] = portrait
	_update_rendering()
	return photo


## A portrait, not yet in the tree, with [param look]'s head, eyes and skin, dressed as
## [param type] (a bow tie for a type that wears one); none for a caller of no type. Every
## portrait of someone the player meets is made here, so whatever a look or type puts on
## the portrait shows on the photos and the transmission screen alike.
static func new_portrait(look: AlienLook, type: PassengerType) -> AlienPortrait:
	var portrait := PORTRAIT.instantiate() as AlienPortrait
	portrait.head_model = look.head
	portrait.eye_style = look.eye_style
	portrait.skin_color = look.skin_color
	portrait.wears_bow_tie = type != null and type.wears_bow_tie
	return portrait


## Scales and places [param portrait], already in the tree, for a close-up of its head in
## a square [constant SLOT] wide around the origin, facing a camera on +z.
static func frame(portrait: AlienPortrait) -> void:
	var head := portrait.get_head_bounds()
	var height := minf(head.size.y, MAX_HEAD)
	var fit := minf(FILL_HEIGHT * SLOT / height, FILL_WIDTH * SLOT / head.size.x)
	portrait.scale = Vector3.ONE * fit
	# The head's top just under the tile's top, unless that leaves the base in view.
	var y := minf(SLOT / 2.0 - HEADROOM * SLOT - head.end.y * fit, -SLOT / 2.0 - SINK)
	portrait.position = Vector3(-head.get_center().x * fit, y, 0.0)


# Takes down the portrait behind [param photo], freeing its slot.
func _remove(photo: AtlasTexture) -> void:
	var portrait: AlienPortrait = _photos.get(photo)
	if not portrait:
		return
	_photos.erase(photo)
	_slots[_slots.find(portrait)] = null
	portrait.queue_free()
	_update_rendering()


## How many portraits it holds.
func get_portrait_count() -> int:
	return _photos.size()


# Pixels from one tile's start to the next.
func _pitch() -> int:
	return TILE + GUTTER


func _update_rendering() -> void:
	render_target_update_mode = UPDATE_ALWAYS if _photos else UPDATE_DISABLED
