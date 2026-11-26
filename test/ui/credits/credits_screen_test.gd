extends GdUnitTestSuite
## The credits screen's people: each a portrait of their own, dressed for what they did.

const PREVIEW := "res://test/previews/creator_portraits_preview.tscn"


func test_the_preview_shows_each_creator_as_their_own_alien_with_their_props() -> void:
	var runner := scene_runner(PREVIEW)
	await runner.simulate_frames(2)

	var portraits: Array[AlienPortrait] = []
	for node: Node in runner.scene().get_children():
		if node is AlienPortrait:
			portraits.append(node as AlienPortrait)
	assert_int(portraits.size()).is_equal(3)
	# Roni, Marko and Sami: a race each, so no two share a colour or a head.
	var skins: Array[Color] = []
	var heads: Array[PackedScene] = []
	for portrait: AlienPortrait in portraits:
		skins.append(portrait.skin_color)
		heads.append(portrait.head_model)
		# Glasses sit on two eyes.
		assert_int(portrait.eyes.size()).is_equal(2)
	(
		assert_array(skins)
		. is_equal(
			[
				Race.SKIN_COLORS[Race.Type.BLUE],
				Race.SKIN_COLORS[Race.Type.GREEN],
				Race.SKIN_COLORS[Race.Type.ORANGE],
			]
		)
	)
	assert_int(_distinct(heads)).is_equal(3)
	# What each wears and holds: glasses for Roni and Sami, and something of their trade.
	var glasses: Array[bool] = []
	for portrait: AlienPortrait in portraits:
		glasses.append(portrait.find_child("Glasses", true, false) != null)
	assert_array(glasses).is_equal([true, false, true])
	assert_object(portraits[0].find_child("Pencil", true, false)).is_not_null()
	assert_object(portraits[1].find_child("Laptop", true, false)).is_not_null()
	assert_object(portraits[2].find_child("Headphones", true, false)).is_not_null()


func _distinct(heads: Array[PackedScene]) -> int:
	var seen: Dictionary[PackedScene, bool] = {}
	for head: PackedScene in heads:
		seen[head] = true
	return seen.size()
