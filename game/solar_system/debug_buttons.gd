extends Node
## The solar system's buttons on the debug panel: emptying or lowering the fuel, heating
## the bus to where it warns or until it overheats, scaring the passengers, showing
## notices, an incoming transmission whose Answer opens a test quest, a passenger calling
## with a real quest as soon as one can, completing the quest under way, a card of quick
## stop windows and warm charges to try, and a card of buttons that turn the bus's traits
## on or off, as upgrades would.

## The debug panel's group for the fuel, heat and scare buttons.
const BUS_GROUP := "Bus"
## The debug panel's group for the transmissions, quests and notices, shared with The Boss's
## first shift call.
const CALLS_GROUP := FirstShiftCall.DEBUG_GROUP
## The debug panel's group for the trait buttons, one per trait that turns it on or off.
const TRAITS_GROUP := "Traits"
## PROTOTYPE: the debug panel's group for the serve minigames, one button per game.
const SERVE_GROUP := "Serve game"
## PROTOTYPE: the lab for trying the serve minigames, also on the main menu's panel.
const SERVE_LAB_SCENE := "res://game/passengers/serve_minigame_lab_prototype.tscn"
const QUICK_GROUP := "Quick stop"
## The quick stop windows the Quick stop card offers, in seconds.
const QUICK_TIMES: Array[float] = [5.0, 6.0, 7.0, 8.0, 10.0]
## The warm charges it offers, in seconds of holding.
const WARM_CHARGE_TIMES: Array[float] = [0.25, 0.5, 1.0]
## The test quest's made-up caller's passenger type, for its badge.
const TEST_TYPE := preload("res://game/passengers/types/business.tres")

@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
@export var quest_giver: QuestGiver
## Where the test quest's caller is going, and the planet their quest names.
@export var test_destination: Planet
@export var test_flyby_planet: Planet


func _ready() -> void:
	DebugPanel.add_button("Empty fuel", _debug_empty_fuel, self, BUS_GROUP)
	DebugPanel.add_button("Low fuel", _debug_low_fuel, self, BUS_GROUP)
	DebugPanel.add_button("Heat to warning", _debug_heat_to_warning, self, BUS_GROUP)
	DebugPanel.add_button("Overheat", _debug_overheat, self, BUS_GROUP)
	DebugPanel.add_button("Scare passengers", _debug_scare_passengers, self, BUS_GROUP)
	var transmission := _debug_incoming_transmission
	DebugPanel.add_button("Incoming transmission", transmission, self, CALLS_GROUP)
	DebugPanel.add_button("Offer quest", _debug_offer_quest, self, CALLS_GROUP)
	DebugPanel.add_button("Complete quest", _debug_complete_quest, self, CALLS_GROUP)
	DebugPanel.add_button("Test notices", _debug_test_notices, self, CALLS_GROUP)
	for seconds: float in QUICK_TIMES:
		var label := "Quick stop %s s" % String.num(seconds, 2)
		DebugPanel.add_button(label, _debug_quick_time.bind(seconds), self, QUICK_GROUP)
	for seconds: float in WARM_CHARGE_TIMES:
		var label := "Warm charge %s s" % String.num(seconds, 2)
		DebugPanel.add_button(label, _debug_warm_charge_time.bind(seconds), self, QUICK_GROUP)
	for value: int in BusTraits.Type.values():
		var text := "Toggle %s" % String(BusTraits.Type.keys()[value]).capitalize().to_lower()
		var action := _debug_toggle_trait.bind(value as BusTraits.Type)
		DebugPanel.add_button(text, action, self, TRAITS_GROUP)
	for mode: ServeMinigamePrototype.Mode in ServeMinigamePrototype.NAMES:
		var pick := _debug_pick_serve_game.bind(mode)
		DebugPanel.add_button(ServeMinigamePrototype.NAMES[mode], pick, self, SERVE_GROUP)
	DebugPanel.add_button("Everyone asks", _debug_everyone_asks, self, SERVE_GROUP)
	DebugPanel.add_button(
		"Serve games lab", SceneFlow.go_to.bind(SERVE_LAB_SCENE), self, SERVE_GROUP
	)


# How long a quick stop lasts, said in a notice.
func _debug_quick_time(seconds: float) -> void:
	bus.quick_time = seconds
	notices.push("Quick stop %s s" % String.num(seconds, 2), Notice.Kind.INFO, false, 2.0)


# How long a charge started warm takes, said in a notice.
func _debug_warm_charge_time(seconds: float) -> void:
	bus.warm_charge_time = seconds
	notices.push("Warm charge %s s" % String.num(seconds, 2), Notice.Kind.INFO, false, 2.0)


# Empty fuel: in space the tow is offered; at a planet the bus must refuel.
func _debug_empty_fuel() -> void:
	bus.get_fuel_tank().drain()


# Low fuel: a fifth of a tank, under where the low fuel warning shows.
func _debug_low_fuel() -> void:
	var tank := bus.get_fuel_tank()
	tank.fuel = tank.capacity * 0.2


# Heat to warning: the temperature where the gauge turns amber and the warning shows.
func _debug_heat_to_warning() -> void:
	bus.temperature.set_temperature(BusStatusPanel.TEMPERATURE_HIGH)


# Overheat: the bus lets go of the key and the cooldown starts, wherever the bus is.
func _debug_overheat() -> void:
	bus.temperature.set_temperature(bus.temperature.overheat_temperature)


# Scare passengers: everyone on board takes a kick's shock, without anyone being kicked.
func _debug_scare_passengers() -> void:
	cabin.shock(Cabin.KICK_SHOCK)


# Incoming transmission: the test quest's caller calls, and Answer opens the quest.
func _debug_incoming_transmission() -> void:
	var transmission := _test_quest()
	var call := notices.announce_transmission(transmission, true, true)
	call.action_pressed.connect(transmission_panel.open.bind(transmission))


# Offer quest: a passenger on board calls with a quest as soon as one can, in flight.
func _debug_offer_quest() -> void:
	quest_giver.call_soon()


# Complete quest: the quest under way is done, as if the bus had flown past or docked at
# its planet, so its reward, the caller's lift and their dance show. With none under way,
# the first passenger on board gets the lift and the dance alone.
func _debug_complete_quest() -> void:
	var quest := quest_giver.get_quest()
	if quest and quest.get_planet():
		var planet := quest.get_planet()
		quest.goal.bus_moved(planet.global_position, cabin.get_passengers(), true)
		quest.goal.bus_docked(planet)
	elif cabin.get_passengers():
		cabin.get_passengers()[0].admire(quest_giver.done_happiness, true)


# Test notices: one of each other kind, the info closing by itself and the warning with a
# close button.
func _debug_test_notices() -> void:
	notices.push("Right-click a planet to add it to the route.", Notice.Kind.TUTORIAL, true)
	notices.push("The tank is full.", Notice.Kind.INFO, false, 4.0)
	notices.push("Fuel is running low.", Notice.Kind.WARNING, true)
	notices.push("Not enough credits.", Notice.Kind.ERROR, false, 4.0)


# The test quest: the first passenger on board calls with a quest, or a made-up one when
# nobody rides. Answering it does nothing yet.
func _test_quest() -> Transmission:
	var passengers := cabin.get_passengers()
	var transmission: Transmission
	if passengers:
		transmission = Transmission.from_passenger(passengers[0])
	else:
		transmission = Transmission.new()
		transmission.caller_name = "Reizhis"
		transmission.look = AlienLook.random(RandomNumberGenerator.new(), Race.Type.BLUE)
		transmission.race = Race.Type.BLUE
		transmission.type = TEST_TYPE
		transmission.destination = test_destination
	transmission.text = "Please fly past that beautiful planet so I can admire it."
	transmission.quest = "Fly past"
	transmission.quest_planet = test_flyby_planet
	transmission.reward_credits = 40
	transmission.reward_research = 2
	transmission.accept_text = "Yes"
	transmission.decline_text = "No"
	return transmission


# The trait buttons: gives the bus the trait, as an upgrade would, or takes it back out.
func _debug_toggle_trait(type: BusTraits.Type) -> void:
	var traits := bus.get_stats().get_traits()
	if traits.has(type):
		traits.remove(type)
	else:
		traits.add(type)


# PROTOTYPE: every serve button plays this game from now on, and a notice says how.
func _debug_pick_serve_game(mode: ServeMinigamePrototype.Mode) -> void:
	ServeMinigamePrototype.mode = mode
	var text := "%s: %s" % [ServeMinigamePrototype.NAMES[mode], ServeMinigamePrototype.HINTS[mode]]
	notices.push(text, Notice.Kind.INFO, false, 5.0)


# PROTOTYPE: everyone on board with nothing open asks for something, to try a game at once.
# Only in flight: a stop puts a request on hold.
func _debug_everyone_asks() -> void:
	for passenger: Passenger in cabin.get_passengers():
		if passenger.request or passenger.type.needs.is_empty():
			continue
		passenger.request = passenger.type.needs.pick_random()
		passenger.serving = 0.0
		passenger.activity = passenger.request.request_line
