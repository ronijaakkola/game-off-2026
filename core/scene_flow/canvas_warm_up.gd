class_name CanvasWarmUp
extends Control
## Draws a scene's 2D materials for the first time while [SceneFlow]'s black card covers
## them: [method fill] adds a speck for each material the scene's controls and sprites
## hold, hidden ones too, and one for each way they clip their children. A 2D shader
## compiles when it first draws, and a hidden control never draws, so without the specks a
## panel that opens later (a call's notice, the transmission's tube) compiles its shaders
## as it opens, which on the web stalls the game for a frame or more each.
##
## A shader compiles once for each way it is drawn, so a speck is drawn as the control it
## stands for is: a panel's style is triangles, anything else here a rectangle.

## A speck's size, in pixels.
const SPECK := Vector2(8.0, 8.0)


## Adds the specks for [param scene]. They draw with the next frame; call [method clear]
## after it.
func fill(scene: Node) -> void:
	var drawn := {}
	var nodes := scene.find_children("*", "CanvasItem", true, false)
	nodes.append(scene)
	for node: Node in nodes:
		var item := node as CanvasItem
		if item == null:
			continue
		var styled := item is Panel or item is PanelContainer
		if item.material and _is_new(drawn, [_shader_of(item.material), styled]):
			_add_speck(styled).material = item.material
		if (
			item.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED
			and _is_new(drawn, [item.clip_children, styled])
		):
			var mask := _add_speck(styled)
			mask.clip_children = item.clip_children
			var clipped := ColorRect.new()
			clipped.size = SPECK
			mask.add_child(clipped)


## Takes the specks away, and with them their hold on the scene's materials.
func clear() -> void:
	for speck: Node in get_children():
		speck.queue_free()


## How many specks [method fill] added.
func count() -> int:
	return get_child_count()


# Whether [param key] is one [param drawn] doesn't hold yet. It holds it from now on.
func _is_new(drawn: Dictionary, key: Array) -> bool:
	if drawn.has(key):
		return false
	drawn[key] = true
	return true


# What compiles for [param material]: materials on one shader share its programs.
func _shader_of(material: Material) -> Resource:
	var shader_material := material as ShaderMaterial
	return shader_material.shader if shader_material else material


# A speck drawn as a panel's style is, in triangles, when [param styled], else as a
# rectangle.
func _add_speck(styled: bool) -> Control:
	var speck: Control
	if styled:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(2)
		speck = Panel.new()
		speck.add_theme_stylebox_override(&"panel", style)
	else:
		speck = ColorRect.new()
	speck.size = SPECK
	speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speck)
	return speck
