extends GdUnitTestSuite
## A passenger's photo takes a portrait from the studio, and waits for a free slot when
## the studio is full. It wears their type's badges, and their portrait their type's bow tie.

const SCENE := preload("res://game/passengers/passenger_photo.tscn")
const STUDIO := preload("res://game/passengers/portrait_studio.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const BUSINESS := preload("res://game/passengers/types/business.tres")


func test_a_photo_that_finds_the_studio_full_takes_the_next_free_slot() -> void:
	var studio: PortraitStudio = auto_free(STUDIO.instantiate())
	add_child(studio)
	var holders: Array[Node] = []
	for i: int in PortraitStudio.SLOTS:
		var holder: Node = auto_free(Node.new())
		add_child(holder)
		studio.lend(holder, _passenger().look, COMMUTER, func(_photo: AtlasTexture) -> void: pass)
		holders.append(holder)
	var photo: PassengerPhoto = auto_free(SCENE.instantiate())
	photo.studio = studio
	photo.passenger = _passenger()
	add_child(photo)
	assert_object(photo.get_photo()).is_null()

	remove_child(holders[0])

	assert_object(photo.get_photo()).is_not_null()
	assert_int(studio.get_portrait_count()).is_equal(PortraitStudio.SLOTS)


func test_a_photo_wears_a_badge_for_each_of_the_type_s_icons() -> void:
	assert_array(BUSINESS.badges).is_not_empty()
	var photo: PassengerPhoto = auto_free(SCENE.instantiate())
	photo.passenger = _passenger(BUSINESS)
	add_child(photo)
	var icons: Array[Texture2D] = []
	for badge: PhotoBadge in _badges(photo):
		icons.append(badge.get_icon())
	assert_array(icons).is_equal(BUSINESS.badges)

	photo.passenger = _passenger(COMMUTER)

	assert_array(_badges(photo)).is_empty()


func test_a_business_passenger_s_portrait_wears_a_bow_tie_and_a_commuter_s_doesn_t() -> void:
	var studio: PortraitStudio = auto_free(STUDIO.instantiate())
	add_child(studio)
	var worn: Array[bool] = []
	for type: PassengerType in [BUSINESS, COMMUTER]:
		var photo: PassengerPhoto = auto_free(SCENE.instantiate())
		photo.studio = studio
		photo.passenger = _passenger(type)
		add_child(photo)
		worn.append(_wears_bow_tie(photo.get_portrait()))
	assert_array(worn).is_equal([true, false])


func _passenger(type: PassengerType = COMMUTER) -> Passenger:
	var planet: Planet = auto_free(Planet.new())
	return Passenger.new(type, planet, 60.0, 40.0)


func _badges(photo: PassengerPhoto) -> Array[PhotoBadge]:
	var badges: Array[PhotoBadge] = []
	for node: Node in photo.find_children("*", "", true, false):
		if node is PhotoBadge:
			badges.append(node as PhotoBadge)
	return badges


static func _wears_bow_tie(portrait: AlienPortrait) -> bool:
	var ties := portrait.find_children("*Tie", "MeshInstance3D", true, false)
	return ties.size() == 1 and (ties[0] as MeshInstance3D).visible
