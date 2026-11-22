class_name CallerPhoto
extends Control
## A transmission's caller as a small photo, as on the call notice: their portrait in a
## rounded square over a blurred backdrop, framed in their skin colour, dressed as the
## [TransmissionScreen] dresses them. A caller the player doesn't know yet is only their
## outline in the dark room, with a question mark over it; one who sits in the dark, as
## the boss does, is the outline alone. It takes its portrait from [member studio] while it
## is in the tree ([method PortraitStudio.lend]), which takes it back when it leaves; when
## the studio is full it waits for the next free slot. Without a studio or a caller the
## square stays empty.

## Where the portrait is rendered. Set it before the photo enters the tree.
var studio: PortraitStudio

var _caller: Transmission
var _known := true


func _ready() -> void:
	_show()


## Shows [param caller], or with [param known] off, their outline and a question mark.
func show_caller(caller: Transmission, known: bool) -> void:
	if studio:
		studio.take_back(self)
	_caller = caller
	_known = known
	if is_node_ready():
		_show()


func _show() -> void:
	if not _caller:
		return
	var dark := _is_dark()
	(%Mark as Control).visible = not _known
	var backdrop := (%Backdrop as ColorRect).material as ShaderMaterial
	backdrop.set_shader_parameter(
		&"backdrop_color", TransmissionScreen.get_backdrop_color(_caller, dark)
	)
	var border := (%Border as Panel).get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	border.border_color = TransmissionScreen.get_frame_color(_caller, dark)
	(%Border as Panel).add_theme_stylebox_override(&"panel", border)
	if studio and not studio.get_lent_portrait(self) and is_inside_tree():
		studio.lend(self, _caller.look, _caller.type, _on_lent)


# The studio lent the photo its tile, or took it back with null.
func _on_lent(photo: AtlasTexture) -> void:
	if photo:
		TransmissionScreen.dress(studio.get_lent_portrait(self), _caller, _is_dark())
	(%Photo as TextureRect).texture = photo


func _is_dark() -> bool:
	return _caller.shadowed or not _known
