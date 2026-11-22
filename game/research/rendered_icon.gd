class_name RenderedIcon
extends RefCounted
## The research tiles' rendered icons: full-colour pictures rendered in Blender in the
## game's two-tone look, each saved at several sizes with a white silhouette beside each
## (tools/research_icons/). An upgrade's icon is its 36 px file. A tile shows the size
## nearest above what it covers on screen, so the picture barely scales and stays crisp;
## shrunk several times at draw time, its edges would break up.

const FOLDER := "res://game/research/icons/rendered/"
## The sizes each icon is saved in, in pixels: a tile's at the UI's scale of 1, 1.5, 2, 3
## and 4, and exactly at a full HD (60) and a 1440p (80) window.
const SIZES: Array[int] = [36, 54, 60, 72, 80, 108, 144]


## Whether [param icon] is a rendered icon rather than a line icon.
static func is_rendered(icon: Texture2D) -> bool:
	return icon != null and icon.resource_path.begins_with(FOLDER)


## [param icon]'s file in the size nearest above [param pixels], or its white silhouette
## when [param silhouette].
static func sized(icon: Texture2D, pixels: float, silhouette: bool) -> Texture2D:
	var size: int = SIZES[-1]
	for each: int in SIZES:
		# A shade under counts as a fit: scaling up 5% is invisible, and the next size down is
		# the sharper picture.
		if each >= pixels * 0.95:
			size = each
			break
	var name := icon.resource_path.get_basename().trim_suffix("_%d" % SIZES[0])
	return load("%s%s_%d.png" % [name, "_silhouette" if silhouette else "", size])
