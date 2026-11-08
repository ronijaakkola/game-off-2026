extends GdUnitTestSuite
## A planet icon draws with a material of its own, so icons side by side each show their
## own planet, and a scene that sets one on it fails loudly.


func test_two_icons_each_show_their_own_planet() -> void:
	var colors: Array[Color] = [Color.ORANGE, Color.TEAL]
	var icons: Array[PlanetIcon] = []
	for color: Color in colors:
		var planet: Planet = auto_free(Planet.new())
		planet.icon_color = color
		var icon: PlanetIcon = auto_free(PlanetIcon.new())
		add_child(icon)
		icon.planet = planet
		icons.append(icon)

	for i: int in icons.size():
		var shown: Color = (icons[i].material as ShaderMaterial).get_shader_parameter(&"color")
		assert_that(shown).is_equal(colors[i])


func test_an_icon_given_a_material_by_its_scene_logs_an_error() -> void:
	var icon: PlanetIcon = auto_free(PlanetIcon.new())
	icon.name = "SharedIcon"
	icon.material = ShaderMaterial.new()

	await (
		assert_error(func() -> void: add_child(icon))
		. is_push_error(
			"SharedIcon: PlanetIcon makes its own material; remove the one its scene sets"
		)
	)
