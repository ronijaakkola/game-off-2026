class_name AlienLook
extends RefCounted
## What a passenger looks like in their portrait: one of their [Race]'s head shapes and an
## eye style, for now each picked at random, and their race's skin colour.

## Each race's head shapes. A race's heads share a build, so its shape shows the race as
## well as its colour, and differ in a detail. Blue are tall and smooth with eyes in the
## face; orange are low mounds with no neck; green have a thin neck, with their eyes out on
## the ends of stalks or a bar.
const HEADS: Dictionary[Race.Type, Array] = {
	Race.Type.BLUE:
	[
		preload("res://game/passengers/models/head_dome.glb"),
		preload("res://game/passengers/models/head_bean.glb"),
	],
	Race.Type.ORANGE:
	[
		preload("res://game/passengers/models/head_blob.glb"),
		preload("res://game/passengers/models/head_mound.glb"),
	],
	Race.Type.GREEN:
	[
		preload("res://game/passengers/models/head_stalks.glb"),
		preload("res://game/passengers/models/head_hammer.glb"),
	],
}
const EYE_STYLES: Array[AlienEyeStyle] = [
	preload("res://game/passengers/eye_styles/googly.tres"),
	preload("res://game/passengers/eye_styles/bead.tres"),
]
var head: PackedScene
var eye_style: AlienEyeStyle
var skin_color: Color


## A look in [param race]'s skin colour and one of its head shapes, with every other part
## picked by [param rng].
static func random(rng: RandomNumberGenerator, race: Race.Type) -> AlienLook:
	var look := AlienLook.new()
	var heads := HEADS[race]
	look.head = heads[rng.randi_range(0, heads.size() - 1)] as PackedScene
	look.eye_style = EYE_STYLES[rng.randi_range(0, EYE_STYLES.size() - 1)]
	look.skin_color = Race.SKIN_COLORS[race]
	return look


## The look [method to_save] gave, for a passenger of [param race]. A part it doesn't
## name is the first of its kind.
static func from_save(saved: Dictionary, race: Race.Type) -> AlienLook:
	var look := AlienLook.new()
	var heads := HEADS[race]
	look.head = heads[clampi(int(saved.get("head", 0)), 0, heads.size() - 1)] as PackedScene
	look.eye_style = EYE_STYLES[clampi(int(saved.get("eyes", 0)), 0, EYE_STYLES.size() - 1)]
	look.skin_color = Race.SKIN_COLORS[race]
	return look


## Which of [param race]'s heads and which eye style it has, for a save game. The skin
## colour comes from the race.
func to_save(race: Race.Type) -> Dictionary:
	return {"head": maxi(HEADS[race].find(head), 0), "eyes": maxi(EYE_STYLES.find(eye_style), 0)}
