extends GdUnitTestSuite
## A passenger's photo takes a portrait from the studio, and waits for a free slot when
## the studio is full. It wears their type's badges.

const SCENE := preload("res://game/passengers/passenger_photo.tscn")
const STUDIO := preload("res://game/passengers/portrait_studio.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const BUSINESS := preload("res://game/passengers/types/business.tres")


func test_a_photo_that_finds_the_studio_full_takes_the_next_free_slot() -> void:
	var studio: PortraitStudio = auto_free(STUDIO.instantiate())
	add_child(studio)
	var taken: Array[AtlasTexture] = []
	for i: int in PortraitStudio.SLOTS:
		taken.append(studio.add(_passenger().look))
	var photo: PassengerPhoto = auto_free(SCENE.instantiate())
	photo.studio = studio
	photo.passenger = _passenger()
	add_child(photo)
	assert_object(photo.get_photo()).is_null()

	studio.remove(taken[0])

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


func _passenger(type: PassengerType = COMMUTER) -> Passenger:
	var planet: Planet = auto_free(Planet.new())
	return Passenger.new(type, planet, 60.0, 40.0)


func _badges(photo: PassengerPhoto) -> Array[PhotoBadge]:
	var badges: Array[PhotoBadge] = []
	for node: Node in photo.find_children("*", "", true, false):
		if node is PhotoBadge:
			badges.append(node as PhotoBadge)
	return badges
