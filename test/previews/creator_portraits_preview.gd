extends Node3D
## The credits' three creator portraits side by side, each framed as a photo frames it
## over a square in its backdrop colour, for a visual check of what they wear and hold.

const SPACING := 1.15


func _ready() -> void:
	var creators := CreatorPortrait.Creator.values()
	for i: int in creators.size():
		var creator := creators[i] as CreatorPortrait.Creator
		var x := (i - (creators.size() - 1) / 2.0) * SPACING
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * PortraitStudio.SLOT
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Race.BACKDROP_COLORS[CreatorPortrait.RACES[creator]]
		var backdrop := MeshInstance3D.new()
		backdrop.mesh = quad
		backdrop.material_override = material
		backdrop.position = Vector3(x, 0.0, -2.0)
		add_child(backdrop)
		var portrait := CreatorPortrait.new_portrait(creator)
		add_child(portrait)
		CreatorPortrait.frame(portrait, creator)
		portrait.position.x += x
		CreatorPortrait.dress(portrait, creator)
