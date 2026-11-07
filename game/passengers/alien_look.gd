class_name AlienLook
extends RefCounted
## What a passenger looks like in their portrait: a head shape, an eye style and a skin
## colour, for now each picked at random.

const HEADS: Array[PackedScene] = [
	preload("res://game/passengers/models/head_dome.glb"),
	preload("res://game/passengers/models/head_blob.glb"),
	preload("res://game/passengers/models/head_stalks.glb"),
	preload("res://game/passengers/models/head_bean.glb"),
	preload("res://game/passengers/models/head_hammer.glb"),
]
const EYE_STYLES: Array[AlienEyeStyle] = [
	preload("res://game/passengers/eye_styles/googly.tres"),
	preload("res://game/passengers/eye_styles/bead.tres"),
]
## The races' skin colours: teal, coral and mustard, hues the planets don't use.
const SKIN_COLORS: Array[Color] = [
	Color(0.3, 0.8, 0.7),
	Color(0.98, 0.52, 0.47),
	Color(0.95, 0.76, 0.3),
]

var head: PackedScene
var eye_style: AlienEyeStyle
var skin_color: Color


## A look with every part picked by [param rng].
static func random(rng: RandomNumberGenerator) -> AlienLook:
	var look := AlienLook.new()
	look.head = HEADS[rng.randi_range(0, HEADS.size() - 1)]
	look.eye_style = EYE_STYLES[rng.randi_range(0, EYE_STYLES.size() - 1)]
	look.skin_color = SKIN_COLORS[rng.randi_range(0, SKIN_COLORS.size() - 1)]
	return look
