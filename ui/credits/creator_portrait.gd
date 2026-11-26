class_name CreatorPortrait
extends RefCounted
## The people who made the game as portraits, for the credits: each is one of the
## passengers' heads in its race's skin colour, a different race each, with glasses for
## those who wear them and something of their trade: a pencil for the designer, a laptop for the
## programmer, headphones for the one who made the sound. What they wear and hold is built
## from plain shapes in the portraits' two-tone light, as a passenger's food is.

enum Creator { RONI = 0, MARKO = 1, SAMI = 2 }

## Whose head each has: the first of that race's.
const RACES: Dictionary[Creator, Race.Type] = {
	Creator.RONI: Race.Type.BLUE,
	Creator.MARKO: Race.Type.GREEN,
	Creator.SAMI: Race.Type.ORANGE,
}
const GLASSES_COLOR := Color(0.12, 0.1, 0.24)
const PENCIL_COLOR := Color(0.98, 0.78, 0.25)
const WOOD_COLOR := Color(0.93, 0.76, 0.56)
const LEAD_COLOR := Color(0.15, 0.13, 0.25)
const LAPTOP_COLOR := Color(0.78, 0.79, 0.88)
const LAPTOP_MARK_COLOR := Color(0.36, 0.62, 0.95)
const CUP_COLOR := Color(0.93, 0.33, 0.45)
const BAND_COLOR := Color(0.15, 0.13, 0.25)
## A lens's rim, inside and outside, in eye radii, and how far in front of the eye it sits.
const RIM := Vector2(1.12, 1.38)
const RIM_FORWARD := 0.45
## The pieces the headphones' band is made of, over the head from cup to cup.
const BAND_PIECES := 20
## A headphone cup: its radius and how far out from the middle it sits, as shares of half
## the head's width, and how far it leans in at the top, in radians.
const CUP_RADIUS := 0.37
const CUP_OUT := 1.0
## How far under the eyes the cups sit, as a share of half the head's width: where the
## head is widest.
const CUP_DROP := 0.14
const CUP_LEAN := 0.18
## How thick the band is, as a share of half the head's width.
const BAND_THICKNESS := 0.07
## How much smaller the one in headphones is framed, so the cups stay inside the photo.
const HEADPHONES_FIT := 0.78


## A portrait of [param creator], not yet in the tree. Once it is, [method dress] it.
static func new_portrait(creator: Creator) -> AlienPortrait:
	var race := RACES[creator]
	var look := AlienLook.new()
	look.skin_color = Race.SKIN_COLORS[race]
	look.eye_style = AlienLook.EYE_STYLES[0]
	# The orange race's first head has one eye, which takes no glasses.
	look.head = AlienLook.HEADS[race][1 if race == Race.Type.ORANGE else 0]
	return PortraitStudio.new_portrait(look, null)


## Scales and places [param portrait], already in the tree, as [method PortraitStudio.frame]
## does, with room for what [param creator] wears.
static func frame(portrait: AlienPortrait, creator: Creator) -> void:
	PortraitStudio.frame(portrait)
	# On the head's own middle, which a photo this big shows when it is off.
	portrait.position.x = -_head_shape(portrait).get_center().x * portrait.scale.x
	if creator == Creator.SAMI:
		# Shrunk toward the middle of the photo's bottom edge, so the bust's base stays out.
		var bottom := -PortraitStudio.SLOT / 2.0
		portrait.scale *= HEADPHONES_FIT
		portrait.position.x *= HEADPHONES_FIT
		portrait.position.y = bottom + (portrait.position.y - bottom) * HEADPHONES_FIT


## Puts on [param portrait], already in the tree, what [param creator] wears and holds.
static func dress(portrait: AlienPortrait, creator: Creator) -> void:
	match creator:
		Creator.RONI:
			_add_glasses(portrait)
			_add_pencil(portrait)
		Creator.MARKO:
			_add_laptop(portrait)
		Creator.SAMI:
			_add_glasses(portrait)
			_add_headphones(portrait)


# A node that moves with the head, whose space is the portrait's own as it stands now. It
# hangs from an eye, the one part of the head a portrait shares.
static func _on_head(portrait: AlienPortrait, named: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = named
	portrait.eyes[0].add_child(holder)
	holder.global_transform = portrait.global_transform
	return holder


# Each eye's centre in the portrait's space, and their radius there.
static func _eye_centres(portrait: AlienPortrait) -> Array[Vector3]:
	var centres: Array[Vector3] = []
	for eye: MeshInstance3D in portrait.eyes:
		centres.append(portrait.to_local(eye.global_position))
	return centres


static func _eye_radius(portrait: AlienPortrait) -> float:
	var eye := portrait.global_transform.affine_inverse() * portrait.eyes[0].global_transform
	return eye.basis.get_scale().x


# A round rim in front of each eye and a bridge between them.
static func _add_glasses(portrait: AlienPortrait) -> void:
	var worn := _on_head(portrait, "Glasses")
	var radius := _eye_radius(portrait)
	var centres := _eye_centres(portrait)
	var front := centres[0].z
	for centre: Vector3 in centres:
		front = maxf(front, centre.z)
	front += radius * RIM_FORWARD
	# Eyes close together share the rim between them.
	var outer := radius * RIM.y
	if centres.size() > 1:
		outer = minf(outer, absf(centres[0].x - centres[1].x) / 2.0 + radius * 0.06)
	var rim := TorusMesh.new()
	rim.inner_radius = outer - radius * (RIM.y - RIM.x)
	rim.outer_radius = outer
	rim.rings = 32
	rim.ring_segments = 8
	for centre: Vector3 in centres:
		var lens := _part(rim, GLASSES_COLOR)
		lens.rotation.x = PI / 2.0
		lens.position = Vector3(centre.x, centre.y, front)
		worn.add_child(lens)
	if centres.size() < 2:
		return
	var gap := absf(centres[0].x - centres[1].x) - rim.inner_radius * 2.0
	var bridge := BoxMesh.new()
	bridge.size = Vector3(maxf(gap, 0.0), radius * 0.2, radius * 0.2)
	var between := _part(bridge, GLASSES_COLOR)
	between.position = (centres[0] + centres[1]) / 2.0
	between.position.z = front
	worn.add_child(between)


# A pencil held up beside the face, its point up and the rest running off the photo.
static func _add_pencil(portrait: AlienPortrait) -> void:
	var head := portrait.get_head_bounds()
	var width := head.size.x
	var radius := width * 0.07
	var length := width * 3.0
	var pencil := Node3D.new()
	pencil.name = "Pencil"
	pencil.rotation.z = -0.3
	var eye_y := _eye_centres(portrait)[0].y
	pencil.position = Vector3(head.end.x - width * 0.02, eye_y - width * 0.12, head.end.z + radius)
	portrait.add_child(pencil)
	var body := _part(_cylinder(radius, radius, length, 6), PENCIL_COLOR)
	body.position.y = -radius * 3.0 - length / 2.0
	pencil.add_child(body)
	var wood := _part(_cylinder(radius * 0.35, radius, radius * 2.0, 6), WOOD_COLOR)
	wood.position.y = -radius * 2.0
	pencil.add_child(wood)
	var lead := _part(_cylinder(0.0, radius * 0.35, radius, 6), LEAD_COLOR)
	lead.position.y = -radius * 0.5
	pencil.add_child(lead)


# An open laptop seen from behind its lid, across the bottom of the photo.
static func _add_laptop(portrait: AlienPortrait) -> void:
	var head := portrait.get_head_bounds()
	var width := head.size.x
	var lid_size := Vector3(width * 1.25, width * 0.8, width * 0.05)
	var box := BoxMesh.new()
	box.size = lid_size
	var lid := _part(box, LAPTOP_COLOR)
	lid.name = "Laptop"
	lid.rotation.x = -0.12
	# The eyes are up on stalks: the lid's top edge comes a third of the way up the head.
	var top := _eye_centres(portrait)[0].y - width * 0.95
	lid.position = Vector3(head.get_center().x, top - lid_size.y / 2.0, head.end.z + width * 0.3)
	portrait.add_child(lid)
	var mark := _part(_cylinder(width * 0.09, width * 0.09, width * 0.02, 24), LAPTOP_MARK_COLOR)
	mark.rotation.x = PI / 2.0
	mark.position = Vector3(0.0, lid_size.y * 0.12, lid_size.z / 2.0)
	lid.add_child(mark)


# Headphones on the head: at each side a cushion pressed against the head with a cup
# outside it, and a round band over the head between them.
static func _add_headphones(portrait: AlienPortrait) -> void:
	var worn := _on_head(portrait, "Headphones")
	var head := _head_shape(portrait)
	var half := head.size.x / 2.0
	var centre := Vector3(head.get_center().x, _eye_centres(portrait)[0].y, head.get_center().z)
	centre.y -= half * CUP_DROP
	var ball := SphereMesh.new()
	ball.radius = half * CUP_RADIUS
	ball.height = ball.radius * 2.0
	for side: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = centre + Vector3(side * half * CUP_OUT, 0.0, 0.0)
		# The cups lean in at the top, as the sides of the head do.
		ear.rotation.z = -side * CUP_LEAN
		worn.add_child(ear)
		var cushion := _part(ball, BAND_COLOR)
		cushion.scale = Vector3(0.3, 0.92, 0.92)
		ear.add_child(cushion)
		var cup := _part(ball, CUP_COLOR)
		cup.scale = Vector3(0.38, 1.0, 1.0)
		cup.position.x = side * ball.radius * 0.4
		ear.add_child(cup)
	# The band is a half circle from cup to cup, as on real headphones: far too big for a
	# head this low, so it stands clear above it.
	var radius := half * (CUP_OUT + CUP_RADIUS * 0.3)
	var step := PI / BAND_PIECES
	var piece := _cylinder(half * BAND_THICKNESS, half * BAND_THICKNESS, radius * step * 1.2, 12)
	for i: int in BAND_PIECES:
		var angle := (i + 0.5) * step
		var link := _part(piece, BAND_COLOR)
		link.position = centre + Vector3(cos(angle), sin(angle), 0.0) * radius
		# Each piece lies along the arch where it sits.
		link.rotation.z = angle
		worn.add_child(link)


# The box round the head's own shape in the portrait's space, without what is on it.
# [method AlienPortrait.get_head_bounds] also takes in the food a portrait keeps out of
# view, which reaches off to one side, so nothing can be centred on it.
static func _head_shape(portrait: AlienPortrait) -> AABB:
	var pattern := "*" + AlienPortrait.HEAD_SUFFIX
	var meshes: Array[MeshInstance3D] = []
	for node: Node in portrait.find_children(pattern, "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	if meshes.is_empty():
		return portrait.get_head_bounds()
	return MeshBounds.around(meshes, portrait.global_transform.affine_inverse())


static func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func _part(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = AlienPortrait.BODY_SHADER
	material.set_shader_parameter(&"light_source", AlienPortrait.LIGHT_DIRECTION)
	material.set_shader_parameter(&"light_is_directional", true)
	material.set_shader_parameter(&"color", color)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	return part
