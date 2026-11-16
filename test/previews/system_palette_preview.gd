extends Node
## The solar system recoloured with one of the colour experiments below, for comparing how
## levels in other colours could look: the sky, the star and its halo, the heat zone, the
## orbit lines, the planets' night tint, and each planet's bands and the Giant's rings.
## Name a palette after `--`: `uv run tools/check.py capture <this scene> -- red_dwarf`.
## With none, or `current`, it keeps the scene's own colours. `near` keeps the game's own
## zoom; otherwise the camera pulls back so Frost shows too.
## Only colours change, so each experiment can be made with the tools the game already has.

## Each colour by what it paints. `planets` gives each planet its base, mid and top band,
## with a fourth for Frost's caps; `rings` the Giant's two ring colours.
const PALETTES: Dictionary[String, Dictionary] = {
	"red_dwarf":
	{
		"sky": [Color("#2a1020"), Color("#3d1526"), Color("#4a1f1a"), Color("#ffd9c7")],
		"star": [Color("#ff6a3d"), Color("#ff4a2a")],
		"heat": [Color("#ff7a4a"), Color("#ff3a2a"), Color("#ff6a3a")],
		"orbit": Color("#ffc0b0"),
		"night": Color("#d9a3b8"),
		"planets":
		{
			"Ember": [Color("#e8b04a"), Color("#c98a2e"), Color("#f5d58a")],
			"Terra": [Color("#4fb8a8"), Color("#8fe0c8"), Color("#2f8f86")],
			"Moon": [Color("#ffe8de"), Color("#f0c8bc"), Color("#f0c8bc")],
			"Giant": [Color("#b05aa8"), Color("#8a3f8f"), Color("#e090c8")],
			"Frost": [Color("#9fc4ff"), Color("#c9dcff"), Color("#eef4ff"), Color("#ffffff")],
		},
		"rings": [Color("#ffb38a"), Color("#e08a6a")],
	},
	"blue_giant":
	{
		"sky": [Color("#0f2238"), Color("#133a55"), Color("#1a2a5a"), Color("#e0f4ff")],
		"star": [Color("#d8f0ff"), Color("#7ac8ff")],
		"heat": [Color("#8ad0ff"), Color("#ffffff"), Color("#9adcff")],
		"orbit": Color("#c0e4ff"),
		"night": Color("#a8bde6"),
		"planets":
		{
			"Ember": [Color("#f2a65a"), Color("#d9824a"), Color("#ffd29a")],
			"Terra": [Color("#6ad1a0"), Color("#b4f0c8"), Color("#3fa880")],
			"Moon": [Color("#eef6ff"), Color("#c6d8f0"), Color("#c6d8f0")],
			"Giant": [Color("#7a8cff"), Color("#5a6ae0"), Color("#b8c4ff")],
			"Frost": [Color("#d8c8ff"), Color("#ece4ff"), Color("#ffffff"), Color("#ffffff")],
		},
		"rings": [Color("#ffd0a0"), Color("#e8b080")],
	},
	"deep_sea":
	{
		"sky": [Color("#0b2a2e"), Color("#0f3e42"), Color("#14304a"), Color("#d8fff4")],
		"star": [Color("#ffe680"), Color("#ffd060")],
		"heat": [Color("#ffd27a"), Color("#ff8a5a"), Color("#ffc070")],
		"orbit": Color("#b8fff0"),
		"night": Color("#8fc4c8"),
		"planets":
		{
			"Ember": [Color("#ff8a6a"), Color("#e8604a"), Color("#ffc0a0")],
			"Terra": [Color("#ffd85a"), Color("#fff0a0"), Color("#e0b030")],
			"Moon": [Color("#f0fff8"), Color("#c0e8dc"), Color("#c0e8dc")],
			"Giant": [Color("#3fc4c8"), Color("#2a9aa8"), Color("#a8f0e8")],
			"Frost": [Color("#c8a0ff"), Color("#e0ccff"), Color("#f4ecff"), Color("#ffffff")],
		},
		"rings": [Color("#ff9ac0"), Color("#e070a0")],
	},
	"toxic_nebula":
	{
		"sky": [Color("#16200f"), Color("#253a12"), Color("#2e1a3a"), Color("#eaffc8")],
		"star": [Color("#c8ff4a"), Color("#8aff3a")],
		"heat": [Color("#c8ff6a"), Color("#ffe03a"), Color("#a8ff5a")],
		"orbit": Color("#d8ffb0"),
		"night": Color("#b0b8a0"),
		"planets":
		{
			"Ember": [Color("#b06aff"), Color("#8a48e0"), Color("#d8a8ff")],
			"Terra": [Color("#ff7ab0"), Color("#ffb0d0"), Color("#e04a90")],
			"Moon": [Color("#f4ffe0"), Color("#d0e8b0"), Color("#d0e8b0")],
			"Giant": [Color("#ffb03a"), Color("#e88a20"), Color("#ffe08a")],
			"Frost": [Color("#7ae8ff"), Color("#b8f4ff"), Color("#e8fcff"), Color("#ffffff")],
		},
		"rings": [Color("#b8ff7a"), Color("#88d850")],
	},
	"bubblegum":
	{
		"sky": [Color("#3a1745"), Color("#5a1f5e"), Color("#2a2a6a"), Color("#fff0fa")],
		"star": [Color("#fff6d0"), Color("#ffd0e8")],
		"heat": [Color("#ffd0e0"), Color("#ff8ab0"), Color("#ffc0e0")],
		"orbit": Color("#ffd0f0"),
		"night": Color("#c8a0e0"),
		"planets":
		{
			"Ember": [Color("#ffb86a"), Color("#ff9a5a"), Color("#ffe0a8")],
			"Terra": [Color("#7ae0c0"), Color("#b8f8e0"), Color("#4ac0a0")],
			"Moon": [Color("#fff8ff"), Color("#f0d8f8"), Color("#f0d8f8")],
			"Giant": [Color("#8ab8ff"), Color("#6a90f0"), Color("#c8dcff")],
			"Frost": [Color("#ff8ac8"), Color("#ffb8e0"), Color("#ffe8f4"), Color("#ffffff")],
		},
		"rings": [Color("#ffe08a"), Color("#ffc860")],
	},
	"synthwave":
	{
		"sky": [Color("#12082a"), Color("#3a0f5a"), Color("#5a0f48"), Color("#ffd0ff")],
		"star": [Color("#ff7a5a"), Color("#ff3a9a")],
		"heat": [Color("#ff6ab0"), Color("#ff3a5a"), Color("#ff5ac8")],
		"orbit": Color("#ff8ae8"),
		"night": Color("#9a7ae0"),
		"planets":
		{
			"Ember": [Color("#ffd23a"), Color("#ffaa2a"), Color("#fff08a")],
			"Terra": [Color("#3ae8ff"), Color("#9af4ff"), Color("#1ab0e0")],
			"Moon": [Color("#f0e0ff"), Color("#c8a8ff"), Color("#c8a8ff")],
			"Giant": [Color("#b04aff"), Color("#8a2ae0"), Color("#e09aff")],
			"Frost": [Color("#ff6ab8"), Color("#ffa8d8"), Color("#ffe0f0"), Color("#ffffff")],
		},
		"rings": [Color("#3affd0"), Color("#2ad0b0")],
	},
	"old_map":
	{
		"sky": [Color("#2a2018"), Color("#3d2e1e"), Color("#2e2a20"), Color("#fff0d0")],
		"star": [Color("#ffcf6a"), Color("#ffb04a")],
		"heat": [Color("#ffc070"), Color("#ff8a4a"), Color("#ffb060")],
		"orbit": Color("#ffe8c0"),
		"night": Color("#c8b090"),
		"planets":
		{
			"Ember": [Color("#d9744a"), Color("#b85a38"), Color("#f0a880")],
			"Terra": [Color("#8ab06a"), Color("#b8d090"), Color("#6a9050")],
			"Moon": [Color("#f4ead8"), Color("#d8c8a8"), Color("#d8c8a8")],
			"Giant": [Color("#e8c070"), Color("#c89a50"), Color("#f8e0a8")],
			"Frost": [Color("#9ab8c8"), Color("#c0d8e0"), Color("#eef6f8"), Color("#ffffff")],
		},
		"rings": [Color("#a8c0c8"), Color("#8aa0a8")],
	},
	"aurora":
	{
		"sky": [Color("#0a1a26"), Color("#0f4a3a"), Color("#3a1a5a"), Color("#e8fff8")],
		"star": [Color("#fff0c8"), Color("#8affc8")],
		"heat": [Color("#a8ffd0"), Color("#ffd080"), Color("#8affd0")],
		"orbit": Color("#c0fff0"),
		"night": Color("#9ab0d0"),
		"planets":
		{
			"Ember": [Color("#ff9a6a"), Color("#e8784a"), Color("#ffc8a0")],
			"Terra": [Color("#4ad0e8"), Color("#90ecff"), Color("#2aa8c8")],
			"Moon": [Color("#ffffff"), Color("#d0e0ee"), Color("#d0e0ee")],
			"Giant": [Color("#c88aff"), Color("#a868f0"), Color("#e8c8ff")],
			"Frost": [Color("#ffd0f0"), Color("#ffe8f8"), Color("#ffffff"), Color("#ffffff")],
		},
		"rings": [Color("#8affc8"), Color("#5ae0a8")],
	},
	"sunset":
	{
		"sky": [Color("#3a1a3a"), Color("#6a2a3a"), Color("#2a2a5a"), Color("#ffe8d8")],
		"star": [Color("#ffe08a"), Color("#ff8a5a")],
		"heat": [Color("#ffb070"), Color("#ff6a4a"), Color("#ffa060")],
		"orbit": Color("#ffd0c0"),
		"night": Color("#b890c8"),
		"planets":
		{
			"Ember": [Color("#ffcf5a"), Color("#f0a83a"), Color("#fff0b0")],
			"Terra": [Color("#5ab8a0"), Color("#90dcc0"), Color("#3a9080")],
			"Moon": [Color("#ffe8e0"), Color("#f0c0c0"), Color("#f0c0c0")],
			"Giant": [Color("#8a6ad0"), Color("#6a4ab0"), Color("#c0a8f0")],
			"Frost": [Color("#6ac0ff"), Color("#a8dcff"), Color("#e8f6ff"), Color("#ffffff")],
		},
		"rings": [Color("#ffb08a"), Color("#f08a6a")],
	},
	"eclipse":
	{
		"sky": [Color("#07070f"), Color("#10101e"), Color("#1a1020"), Color("#ffffff")],
		"star": [Color("#1a1028"), Color("#ffe0a0")],
		"heat": [Color("#ffe0a0"), Color("#ffffff"), Color("#ffd080")],
		"orbit": Color("#ffffff"),
		"night": Color("#8a86b0"),
		"planets":
		{
			"Ember": [Color("#ff9a5a"), Color("#e87a3a"), Color("#ffd0a0")],
			"Terra": [Color("#7ae08a"), Color("#b8f4b0"), Color("#4ab868")],
			"Moon": [Color("#f0eeff"), Color("#c8c4e8"), Color("#c8c4e8")],
			"Giant": [Color("#ffc84a"), Color("#f0a030"), Color("#fff0a0")],
			"Frost": [Color("#ff9ac0"), Color("#ffc4d8"), Color("#fff0f4"), Color("#ffffff")],
		},
		"rings": [Color("#b8b4ff"), Color("#9894e8")],
	},
	"daylight":
	{
		"sky": [Color("#a8b8e0"), Color("#18203a"), Color("#201830"), Color("#ffffff")],
		"star": [Color("#ffb030"), Color("#ffffff")],
		"heat": [Color("#ff9a3a"), Color("#ff5a2a"), Color("#ff8a3a")],
		"orbit": Color("#303070"),
		"night": Color("#8a90c8"),
		"planets":
		{
			"Ember": [Color("#e0603a"), Color("#c04a2a"), Color("#f09060")],
			"Terra": [Color("#3aa060"), Color("#6ac080"), Color("#2a8048")],
			"Moon": [Color("#8a80b0"), Color("#6a6098"), Color("#6a6098")],
			"Giant": [Color("#6a5ad0"), Color("#4a3ab0"), Color("#9a8ae8")],
			"Frost": [Color("#d04a8a"), Color("#e07aa8"), Color("#f8d0e4"), Color("#ffffff")],
		},
		"rings": [Color("#ff9a4a"), Color("#e07a2a")],
	},
}
## How far back the camera sits to show every planet, Frost included.
const WIDE_DISTANCE := 55.0
## How far toward Frost the camera looks, from the star.
const FROST_PULL := 0.35


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var system := %SolarSystem as SolarSystem
	if "near" not in args:
		var rig := system.find_child("CameraRig") as CameraRig
		rig.set_distance(WIDE_DISTANCE)
		# Frost starts behind the dock panel, so look a little its way.
		var frost := system.find_child("Frost") as Planet
		rig.move_to(frost.get_body_global_position() * FROST_PULL)
	for arg: String in args:
		if arg in PALETTES:
			_apply(system, PALETTES[arg])
			return
	assert(args.is_empty() or "current" in args or "near" in args, "no palette in %s" % args)


func _apply(system: SolarSystem, palette: Dictionary) -> void:
	var sky := system.find_child("SpaceSky") as SpaceSky
	var sky_colors: Array = palette["sky"]
	sky.background_color = sky_colors[0]
	sky.fog_color = sky_colors[1]
	sky.fog_accent_color = sky_colors[2]
	sky.star_color = sky_colors[3]
	var star := system.find_child("Star") as Node3D
	var star_colors: Array = palette["star"]
	var core := (star.get_node(^"Surface") as MeshInstance3D).get_active_material(0)
	(core as StandardMaterial3D).albedo_color = star_colors[0]
	var halo := (star.get_node(^"Halo") as MeshInstance3D).get_active_material(0)
	_set_keeping_alpha(halo as ShaderMaterial, &"halo_color", star_colors[1])
	var heat := (system.find_child("HeatZoneDisc") as MeshInstance3D).material_override
	var heat_colors: Array = palette["heat"]
	_set_keeping_alpha(heat as ShaderMaterial, &"zone_color", heat_colors[0])
	_set_keeping_alpha(heat as ShaderMaterial, &"hot_color", heat_colors[1])
	_set_keeping_alpha(heat as ShaderMaterial, &"smoke_color", heat_colors[2])
	var planets: Dictionary = palette["planets"]
	for planet_name: String in planets:
		var planet := system.find_child(planet_name) as Planet
		var bands: Array = planets[planet_name]
		var surface := planet.surface_material as ShaderMaterial
		surface.set_shader_parameter(&"base_color", bands[0])
		surface.set_shader_parameter(&"mid_color", bands[1])
		surface.set_shader_parameter(&"top_color", bands[2])
		if bands.size() > 3:
			surface.set_shader_parameter(&"cap_color", bands[3])
		surface.set_shader_parameter(&"shadow_color", palette["night"])
		planet.icon_color = bands[0]
		var orbit := planet.orbit_material as StandardMaterial3D
		var orbit_color: Color = palette["orbit"]
		orbit.albedo_color = Color(orbit_color, orbit.albedo_color.a)
		if planet.ring_material:
			var rings: Array = palette["rings"]
			(planet.ring_material as ShaderMaterial).set_shader_parameter(&"color_a", rings[0])
			(planet.ring_material as ShaderMaterial).set_shader_parameter(&"color_b", rings[1])
			planet.icon_ring_color = rings[0]


# Sets a colour uniform to [param color], keeping the alpha the scene gave it, which is
# what makes the halo and the heat zone see-through.
func _set_keeping_alpha(material: ShaderMaterial, param: StringName, color: Color) -> void:
	var old: Variant = material.get_shader_parameter(param)
	if old == null:
		# Not set in the scene, so the shader's own default holds.
		old = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), param)
	var alpha := (old as Color).a if old is Color else 1.0
	material.set_shader_parameter(param, Color(color, alpha))
