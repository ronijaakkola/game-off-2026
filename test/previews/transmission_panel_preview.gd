extends Node
## The solar system with a transmission open: the boss's message by default, or with
## `quest` a passenger's quest with a reward and Yes and No. `skip` shows it all at once,
## as a click on the modal does.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var transmission := Transmission.new()
	if "quest" in args:
		transmission.caller_name = "Reizhis"
		transmission.look = AlienLook.random(RandomNumberGenerator.new(), Race.Type.BLUE)
		transmission.race = Race.Type.BLUE
		transmission.type = preload("res://game/passengers/types/business.tres")
		transmission.destination = $SolarSystem.find_child("Giant") as Planet
		transmission.text = "Please stop the bus to let me admire that beautiful planet."
		transmission.quest = "Stop the bus near"
		transmission.quest_planet = $SolarSystem.find_child("Frost") as Planet
		transmission.reward_credits = 40
		transmission.reward_research = {Race.Type.BLUE: 2}
		transmission.accept_text = "Yes"
		transmission.decline_text = "No"
	else:
		transmission.caller_name = "Your boss"
		transmission.look = AlienLook.random(RandomNumberGenerator.new(), Race.Type.GREEN)
		transmission.mood = Passenger.Mood.HAPPY
		transmission.text = (
			"Good work out there, driver. Hold a 4.0 rating until the end of the week"
			+ " and we will talk about that promotion."
		)
	var panel := $SolarSystem/TransmissionPanel as TransmissionPanel
	panel.open(transmission)
	if "skip" in args:
		panel.skip()
