extends GdUnitTestSuite

const SceneStrings := preload("res://tools/text_desk/scene_strings.gd")
const Found := preload("res://tools/text_desk/found_text.gd")

const SOURCE := """[gd_scene format=3 uid="uid://abc"]

[ext_resource type="Script" path="res://some/script.gd" id="1_script"]

[sub_resource type="Resource" id="Resource_speed"]
title = "Speed 1"
description = "The bus flies \\"faster\\"."

[node name="Sol" type="Node3D"]
script = ExtResource("1_script")
arrival_call = "Welcome to Sol.
Get to work."
radius = 2.0

[node name="Card" type="PanelContainer" parent="."]

[node name="Title" type="Label" parent="Card"]
theme_type_variation = &"HeaderLabel"
text = "Credits"
"""


func test_a_key_says_which_section_and_property() -> void:
	var texts := {}
	for found: Found in SceneStrings.scan(SOURCE):
		texts[found.key] = found.value
	(
		assert_dict(texts)
		. is_equal(
			{
				"sub:Resource_speed/title": "Speed 1",
				"sub:Resource_speed/description": 'The bus flies "faster".',
				"node:./arrival_call": "Welcome to Sol.\nGet to work.",
				"node:Card/Title/text": "Credits",
			}
		)
	)


func test_a_written_text_reads_back_the_same() -> void:
	for value: String in ["Plain.", 'She said "no".', "A back\\slash", "Two\nlines"]:
		var source := "[resource]\ntitle = %s\nnext = 1\n" % SceneStrings.write_literal(value)
		var found := SceneStrings.scan(source)
		assert_int(found.size()).is_equal(1)
		assert_str(found[0].value).is_equal(value)
