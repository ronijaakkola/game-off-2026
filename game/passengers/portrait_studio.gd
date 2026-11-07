class_name PortraitStudio
extends SubViewport
## Renders every passenger portrait on screen in one pass: each [AlienPortrait] stands in
## its own slot of a row under one orthographic camera, and a card shows its slot's tile
## of the rendered texture. The photo is a close-up of the head, so the bust reaches down
## past its tile; with the slots in one row, that part falls outside the render rather
## than in a neighbour's tile. One pass for all of them is cheaper on the web than a viewport
## per card. It renders only while it holds a portrait.

## A slot was freed, so a photo that found the studio full can try again.
signal slot_freed

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

# The portrait in each slot, or null.
var _slots: Array[AlienPortrait] = []
var _photos: Dictionary[AtlasTexture, AlienPortrait] = {}


func _ready() -> void:
	size = Vector2i(SLOTS * _pitch(), _pitch())
	(%Camera as Camera3D).size = _pitch() * SLOT / TILE
	_slots.resize(SLOTS)
	_update_rendering()


## Puts a portrait of [param look] in a free slot and returns the photo of it to show, or
## null when every slot is taken.
func add(look: AlienLook) -> AtlasTexture:
	var slot := _slots.find(null)
	if slot < 0:
		return null
	var portrait := PORTRAIT.instantiate() as AlienPortrait
	portrait.head_model = look.head
	portrait.eye_style = look.eye_style
	portrait.skin_color = look.skin_color
	%Portraits.add_child(portrait)
	var head := portrait.get_head_bounds()
	var height := minf(head.size.y, MAX_HEAD)
	var fit := minf(FILL_HEIGHT * SLOT / height, FILL_WIDTH * SLOT / head.size.x)
	portrait.scale = Vector3.ONE * fit
	var pitch := _pitch() * SLOT / TILE
	# The head's top just under the tile's top, unless that leaves the base in view.
	var y := minf(SLOT / 2.0 - HEADROOM * SLOT - head.end.y * fit, -SLOT / 2.0 - SINK)
	portrait.position = Vector3(
		(slot - (SLOTS - 1) / 2.0) * pitch - head.get_center().x * fit, y, 0.0
	)
	_slots[slot] = portrait
	var photo := AtlasTexture.new()
	photo.atlas = get_texture()
	photo.region = Rect2(slot * _pitch() + GUTTER / 2.0, GUTTER / 2.0, TILE, TILE)
	_photos[photo] = portrait
	_update_rendering()
	return photo


## Takes down the portrait behind [param photo], freeing its slot.
func remove(photo: AtlasTexture) -> void:
	var portrait: AlienPortrait = _photos.get(photo)
	if not portrait:
		return
	_photos.erase(photo)
	_slots[_slots.find(portrait)] = null
	portrait.queue_free()
	_update_rendering()
	slot_freed.emit()


## How many portraits it holds.
func get_portrait_count() -> int:
	return _photos.size()


# Pixels from one tile's start to the next.
func _pitch() -> int:
	return TILE + GUTTER


func _update_rendering() -> void:
	render_target_update_mode = UPDATE_ALWAYS if _photos else UPDATE_DISABLED
