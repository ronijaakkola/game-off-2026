class_name RenderDiagnostics
extends Node
## Debug panel switches, in the "Rendering" group, that each turn off one cost growing with
## the pixels on screen, so a slow frame can be traced where it is slow: in a browser in
## fullscreen. [method describe] names what is off for the FPS readout.
## Glass and stencil rewrite the code of every shader in the scene tree that reads the
## screen or uses the stencil, found by what the code declares, so this names no game file.
## Each material using a shader shares the one cached [Shader], held here once seen, so the
## rewrite reaches later scenes too, and scenes added while a switch is off are searched as
## they come. The bus's exhaust sets its stencil from code, and keeps it. Nothing is saved:
## a reload puts everything back.

const GROUP := "Rendering"
## What a panel shows behind it with the glass off: the glass's navy, opaque.
const NO_GLASS := "vec4(0.1216, 0.102, 0.2784, 1.0)"

var _glass := true
var _stencil := true
var _search_queued := false
# Each shader seen, with its own code from before any switch rewrote it.
var _originals: Dictionary[Shader, String] = {}
var _screen_uniform := RegEx.create_from_string(
	"uniform\\s+sampler2D\\s+(\\w+)\\s*:[^;]*hint_screen_texture"
)


func _ready() -> void:
	var msaa := _debug_set_msaa
	DebugPanel.add_button("MSAA off", msaa.bind(Viewport.MSAA_DISABLED), self, GROUP)
	DebugPanel.add_button("MSAA 2x", msaa.bind(Viewport.MSAA_2X), self, GROUP)
	DebugPanel.add_button("MSAA 4x", msaa.bind(Viewport.MSAA_4X), self, GROUP)
	DebugPanel.add_button("Toggle glass blur", _debug_toggle_glass, self, GROUP)
	DebugPanel.add_button("Toggle stencil", _debug_toggle_stencil, self, GROUP)
	get_tree().node_added.connect(_on_node_added)


## What the switches have changed from the game's own look, such as "MSAA 4x · no glass".
func describe() -> String:
	var msaa := get_tree().root.msaa_3d
	var parts: Array[String] = []
	parts.append("MSAA off" if msaa == Viewport.MSAA_DISABLED else "MSAA %dx" % (1 << msaa))
	if not _glass:
		parts.append("no glass")
	if not _stencil:
		parts.append("no stencil")
	return " · ".join(parts)


func _debug_set_msaa(msaa: Viewport.MSAA) -> void:
	get_tree().root.msaa_3d = msaa


# With the glass off, nothing reads the screen, so Godot stops copying and blurring it.
func _debug_toggle_glass() -> void:
	_glass = not _glass
	_apply()


# With the stencil off, the bus's border draws over the bus too.
func _debug_toggle_stencil() -> void:
	_stencil = not _stencil
	_apply()


# Materials are often set in a node's _ready(), after it enters the tree, so the search
# waits for the end of the frame, once for everything added in it.
func _on_node_added(_node: Node) -> void:
	if (not _glass or not _stencil) and not _search_queued:
		_search_queued = true
		_apply.call_deferred()


func _apply() -> void:
	_search_queued = false
	_find_shaders(get_tree().root)
	for shader: Shader in _originals:
		var code := _rewritten(_originals[shader])
		if shader.code != code:
			shader.code = code


func _rewritten(code: String) -> String:
	if not _glass:
		var found := _screen_uniform.search(code)
		if found:
			var read := RegEx.create_from_string(
				"texture(Lod)?\\(%s,[^)]*\\)" % found.get_string(1)
			)
			code = read.sub(_without_lines(code, "hint_screen_texture"), NO_GLASS, true)
	if not _stencil:
		code = _without_lines(code, "stencil_mode")
	return code


func _without_lines(code: String, containing: String) -> String:
	var kept: Array[String] = []
	for line: String in code.split("\n"):
		if not line.contains(containing):
			kept.append(line)
	return "\n".join(kept)


func _find_shaders(node: Node) -> void:
	var materials: Array[Material] = []
	if node is CanvasItem:
		materials.append((node as CanvasItem).material)
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		materials.append_array([geometry.material_override, geometry.material_overlay])
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface: int in mesh_instance.get_surface_override_material_count():
			materials.append(mesh_instance.get_surface_override_material(surface))
		# An ImmediateMesh can have fewer surfaces than the instance has override slots.
		var mesh := mesh_instance.mesh
		for surface: int in mesh.get_surface_count() if mesh else 0:
			materials.append(mesh.surface_get_material(surface))
	for material: Material in materials:
		while material:
			var shader_material := material as ShaderMaterial
			if shader_material and shader_material.shader:
				_remember(shader_material.shader)
			material = material.next_pass
	for child: Node in node.get_children():
		_find_shaders(child)


func _remember(shader: Shader) -> void:
	if _originals.has(shader):
		return
	var code := shader.code
	if code.contains("hint_screen_texture") or code.contains("stencil_mode"):
		_originals[shader] = code
