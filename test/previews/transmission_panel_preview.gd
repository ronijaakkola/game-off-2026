extends Node
## The solar system with a transmission open: the boss's message by default, from the dark
## or with `revealed` in the light; with `quest` a passenger's quest with a reward and Yes
## and No; or with `goals_met` The Boss's call once every goal is met (`unanswered` for the
## call left ringing); or with `mechanic` the mechanic's first call. `skip` shows it all
## at once, as a click on the modal does.


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
		transmission.reward_research = 2
		transmission.accept_text = "Yes"
		transmission.decline_text = "No"
	elif "goals_met" in args:
		transmission = Transmission.from_boss()
		transmission.caller_name = GoalsMetCall.CALLER
		var unanswered := "unanswered" in args
		transmission.text = GoalsMetCall.UNANSWERED_TEXT if unanswered else GoalsMetCall.TEXT
		transmission.decline_text = GoalsMetCall.ANSWERS[0]
		transmission.accept_text = GoalsMetCall.ANSWERS[1]
		transmission.answers_alike = true
	elif "mechanic" in args:
		transmission = Transmission.from_mechanic()
		transmission.text = MechanicCall.RESEARCH_TEXT
		transmission.decline_text = MechanicCall.RESEARCH_ANSWERS[0]
		transmission.accept_text = MechanicCall.RESEARCH_ANSWERS[1]
		transmission.answers_alike = true
	else:
		transmission = Transmission.from_boss("revealed" in args)
		transmission.mood = Passenger.Mood.HAPPY
		transmission.text = (
			"Good work out there, driver. Hold a 4.0 rating until the end of the week"
			+ " and we will talk about that promotion."
		)
	var panel := $SolarSystem/TransmissionPanel as TransmissionPanel
	panel.open(transmission)
	if "skip" in args:
		panel.skip()
