extends GdUnitTestSuite
## The studio lends its portraits and takes each back as its holder leaves the tree, so a
## slot is never left taken by a photo that is gone; when it is full, holders wait their
## turn for the next free slot.

const STUDIO := preload("res://game/passengers/portrait_studio.tscn")
const CALLER_PHOTO := preload("res://game/transmissions/caller_photo.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")

var _studio: PortraitStudio
var _look: AlienLook
# What each holder was last shown, as the studio handed it over.
var _shown: Dictionary[Node, AtlasTexture] = {}


func before_test() -> void:
	_studio = auto_free(STUDIO.instantiate())
	add_child(_studio)
	_look = AlienLook.random(RandomNumberGenerator.new(), Race.Type.values()[0] as Race.Type)
	_shown.clear()


func test_a_holder_leaving_the_tree_frees_its_slot() -> void:
	var holder := _holder()
	_lend(holder)
	assert_object(_shown[holder]).is_not_null()
	assert_int(_studio.get_portrait_count()).is_equal(1)

	remove_child(holder)

	assert_int(_studio.get_portrait_count()).is_equal(0)
	assert_object(_shown[holder]).is_null()


func test_lending_again_gives_back_the_one_it_held() -> void:
	var holder := _holder()
	_lend(holder)
	_lend(holder)

	assert_int(_studio.get_portrait_count()).is_equal(1)


func test_the_first_in_line_gets_the_next_free_slot_and_one_who_left_the_line_doesn_t() -> void:
	var holders: Array[Node] = []
	for i: int in PortraitStudio.SLOTS:
		holders.append(_holder())
		_lend(holders[-1])
	var gone := _holder()
	var first := _holder()
	var second := _holder()
	for waiting: Node in [gone, first, second]:
		_lend(waiting)
		assert_object(_shown.get(waiting)).is_null()
	remove_child(gone)

	remove_child(holders[0])

	assert_object(_shown.get(gone)).is_null()
	assert_object(_shown.get(first)).is_not_null()
	assert_object(_shown.get(second)).is_null()
	assert_int(_studio.get_portrait_count()).is_equal(PortraitStudio.SLOTS)


func test_a_caller_photo_gives_its_portrait_back_as_it_leaves() -> void:
	var photo: CallerPhoto = auto_free(CALLER_PHOTO.instantiate())
	photo.studio = _studio
	photo.show_caller(Transmission.from_mechanic(), true)
	add_child(photo)
	assert_int(_studio.get_portrait_count()).is_equal(1)

	remove_child(photo)

	assert_int(_studio.get_portrait_count()).is_equal(0)


func _holder() -> Node:
	var holder: Node = auto_free(Node.new())
	add_child(holder)
	return holder


func _lend(holder: Node) -> void:
	_studio.lend(holder, _look, COMMUTER, func(photo: AtlasTexture) -> void: _shown[holder] = photo)
