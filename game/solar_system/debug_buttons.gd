extends Node
## The solar system's buttons on the debug panel: emptying or lowering the fuel, heating
## the bus to where it warns or until it overheats, scaring the passengers, showing
## notices, an incoming transmission whose Answer opens a test quest, a passenger calling
## with a real quest as soon as one can, and a card each of buttons that change the bus's
## stats and turn its traits on or off, as upgrades would.

## The percent of top speed, the fuel tank and portion size the stat buttons add or take
## away, and the seats, on every click.
const STAT_PERCENT := 20
const SEATS := 1
## The debug panel's group for the stat buttons: its own card, opened from the main one.
const STATS_GROUP := "Stats"
## The debug panel's group for the trait buttons, one per trait that turns it on or off.
const TRAITS_GROUP := "Traits"
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
	DebugPanel.add_button("Empty fuel", _debug_empty_fuel, self)
	DebugPanel.add_button("Low fuel", _debug_low_fuel, self)
	DebugPanel.add_button("Heat to warning", _debug_heat_to_warning, self)
	DebugPanel.add_button("Overheat", _debug_overheat, self)
	DebugPanel.add_button("Scare passengers", _debug_scare_passengers, self)
	DebugPanel.add_button("Incoming transmission", _debug_incoming_transmission, self)
	DebugPanel.add_button("Offer quest", _debug_offer_quest, self)
	DebugPanel.add_button("Test notices", _debug_test_notices, self)
	var percent := StatModifier.Kind.PERCENT
	_add_stat_buttons(BusStats.Type.MAX_SPEED, percent, STAT_PERCENT, "% top speed")
	_add_stat_buttons(BusStats.Type.FUEL_CAPACITY, percent, STAT_PERCENT, "% fuel tank")
	_add_stat_buttons(BusStats.Type.SEATS, StatModifier.Kind.FLAT, SEATS, " seat")
	_add_stat_buttons(BusStats.Type.PORTION_SIZE, percent, STAT_PERCENT, "% portions")
	for value: int in BusTraits.Type.values():
		var text := "Toggle %s" % String(BusTraits.Type.keys()[value]).capitalize().to_lower()
		var action := _debug_toggle_trait.bind(value as BusTraits.Type)
		DebugPanel.add_button(text, action, self, TRAITS_GROUP)


# A pair of buttons for the type stat on the Stats card, "+20% top speed" and
# "-20% top speed": one adds step, the other takes it away.
func _add_stat_buttons(
	type: BusStats.Type, kind: StatModifier.Kind, step: int, what: String
) -> void:
	for amount: int in [step, -step]:
		var text := "%+d%s" % [amount, what]
		var action := _debug_change_stat.bind(type, kind, amount)
		DebugPanel.add_button(text, action, self, STATS_GROUP)


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


# Overheat: the route clears and the cooldown starts, wherever the bus is.
func _debug_overheat() -> void:
	bus.temperature.set_temperature(bus.temperature.overheat_temperature)


# Scare passengers: everyone on board takes a kick's shock, without anyone being kicked.
func _debug_scare_passengers() -> void:
	cabin.shock(Cabin.KICK_SHOCK)


# Incoming transmission: the call notice, whose Answer opens the test quest.
func _debug_incoming_transmission() -> void:
	notices.announce_transmission().action_pressed.connect(_open_test_quest)


# Offer quest: a passenger on board calls with a quest as soon as one can, in flight.
func _debug_offer_quest() -> void:
	quest_giver.call_soon()


# Test notices: one of each other kind, the info closing by itself and the warning with a
# close button.
func _debug_test_notices() -> void:
	notices.push("Right-click a planet to add it to the route.", Notice.Kind.TUTORIAL, true)
	notices.push("The tank is full.", Notice.Kind.INFO, false, 4.0)
	notices.push("Fuel is running low.", Notice.Kind.WARNING, true)
	notices.push("Not enough credits.", Notice.Kind.ERROR, false, 4.0)


# The test quest: the first passenger on board calls with a quest, or a made-up one when
# nobody rides. Answering it does nothing yet.
func _open_test_quest() -> void:
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
	transmission.text = "Please stop the bus to let me admire that beautiful planet."
	transmission.quest = "Stop the bus near"
	transmission.quest_planet = test_flyby_planet
	transmission.reward_credits = 40
	transmission.reward_research = {transmission.race: 2}
	transmission.accept_text = "Yes"
	transmission.decline_text = "No"
	transmission_panel.open(transmission)


# The stat buttons, each a modifier like an upgrade's, another with every click. Once the
# stat is at its floor, taking away adds nothing, so the clicks that bring it back up
# count from there.
func _debug_change_stat(type: BusStats.Type, kind: StatModifier.Kind, amount: int) -> void:
	var stats := bus.get_stats()
	var stat := stats.get_stat(type)
	if amount < 0 and stat.get_value() <= stat.minimum:
		return
	stats.add_modifier(StatModifier.new(type, kind, amount))


# The trait buttons: gives the bus the trait, as an upgrade would, or takes it back out.
func _debug_toggle_trait(type: BusTraits.Type) -> void:
	var traits := bus.get_stats().get_traits()
	if traits.has(type):
		traits.remove(type)
	else:
		traits.add(type)
