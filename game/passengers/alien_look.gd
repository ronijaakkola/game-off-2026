class_name AlienLook
extends RefCounted
## What a passenger looks like in their portrait: a head shape and an eye style, for now
## each picked at random, and the skin colour of their [Race].

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
var head: PackedScene
var eye_style: AlienEyeStyle
var skin_color: Color


## A look in [param race]'s skin colour, with every other part picked by [param rng].
static func random(rng: RandomNumberGenerator, race: Race.Type) -> AlienLook:
	var look := AlienLook.new()
	look.head = HEADS[rng.randi_range(0, HEADS.size() - 1)]
	look.eye_style = EYE_STYLES[rng.randi_range(0, EYE_STYLES.size() - 1)]
	look.skin_color = Race.SKIN_COLORS[race]
	return look
