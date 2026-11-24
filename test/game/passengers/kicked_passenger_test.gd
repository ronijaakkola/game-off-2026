extends GdUnitTestSuite
## A kicked passenger screams in their race's voice, and the scream fades out.

const SCENE := preload("res://game/passengers/kicked_passenger.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")


func test_the_figure_screams_a_kicked_clip_of_the_passenger_s_race() -> void:
	var planet: Planet = auto_free(Planet.new())
	var passenger := Passenger.new(COMMUTER, planet, 60.0, 40.0)
	passenger.race = Race.Type.GREEN
	var figure: KickedPassenger = auto_free(SCENE.instantiate())
	add_child(figure)
	figure.throw(Vector3.ZERO, Vector3.RIGHT, Color.WHITE, passenger)
	var kicked := VoiceSpeaker.VOICES[Race.Type.GREEN].kicked
	var screaming := false
	for node: Node in (figure.get_node("%Speaker") as Node).get_children():
		var player := node as AudioStreamPlayer
		if player and player.playing and player.stream in kicked:
			screaming = true
	assert_bool(screaming).is_true()
