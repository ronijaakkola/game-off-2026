class_name CallerPhoto
extends Control
## A transmission's caller as a small photo, as on the call notice: their portrait in a
## rounded square over a blurred backdrop, framed in their skin colour, dressed as the
## [TransmissionScreen] dresses them. A caller the player doesn't know yet is only their
## outline in the dark room, with a question mark over it; one who sits in the dark, as
## the boss does, is the outline alone. It takes its portrait from [member studio] while it
## is in the tree and gives it back when it leaves; when the studio is full it waits for
## the next free slot. Without a studio or a caller the square stays empty.

## Where the portrait is rendered. Set it before the photo enters the tree.
var studio: PortraitStudio

var _caller: Transmission
var _known := true
# The tile of the studio's render this photo shows, or null.
var _photo: AtlasTexture


func _ready() -> void:
	_show()


func _exit_tree() -> void:
	_give_back()


## Shows [param caller], or with [param known] off, their outline and a question mark.
func show_caller(caller: Transmission, known: bool) -> void:
	_give_back()
	_caller = caller
	_known = known
	if is_node_ready():
		_show()


func _show() -> void:
	if not _caller:
		return
	var dark := _caller.shadowed or not _known
	(%Mark as Control).visible = not _known
	var backdrop := (%Backdrop as ColorRect).material as ShaderMaterial
	backdrop.set_shader_parameter(
		&"backdrop_color", TransmissionScreen.get_backdrop_color(_caller, dark)
	)
	var border := (%Border as Panel).get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	border.border_color = TransmissionScreen.get_frame_color(_caller, dark)
	(%Border as Panel).add_theme_stylebox_override(&"panel", border)
	if studio and not _photo and is_inside_tree():
		_photo = studio.add(_caller.look, _caller.type)
		if _photo:
			TransmissionScreen.dress(studio.get_portrait(_photo), _caller, dark)
		elif not studio.slot_freed.is_connected(_show):
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
