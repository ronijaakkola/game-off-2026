extends GdUnitTestSuite
## A passenger's photo takes a portrait from the studio, and waits for a free slot when
## the studio is full.

const SCENE := preload("res://game/passengers/passenger_photo.tscn")
const STUDIO := preload("res://game/passengers/portrait_studio.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")


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


func _passenger() -> Passenger:
	var planet: Planet = auto_free(Planet.new())
	return Passenger.new(COMMUTER, planet, 60.0, 40.0)
