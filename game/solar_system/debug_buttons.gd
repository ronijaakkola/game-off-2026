extends Node
## The solar system's buttons on the debug panel: emptying or lowering the fuel, scaring the
## passengers, showing notices, and a card each of buttons that change the bus's stats and
## turn its traits on or off, as upgrades would.

## The percent of top speed, the fuel tank and portion size the stat buttons add or take
## away, and the seats, on every click.
const STAT_PERCENT := 20
const SEATS := 1
## The debug panel's group for the stat buttons: its own card, opened from the main one.
const STATS_GROUP := "Stats"
## The debug panel's group for the trait buttons, one per trait that turns it on or off.
const TRAITS_GROUP := "Traits"
## PROTOTYPE: the debug panel's group for the serve minigames, one button per game.
const SERVE_GROUP := "Serve game"
## PROTOTYPE: the lab for trying the serve minigames, also on the main menu's panel.
const SERVE_LAB_SCENE := "res://game/passengers/serve_minigame_lab_prototype.tscn"

@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack


func _ready() -> void:
	DebugPanel.add_button("Empty fuel", _debug_empty_fuel, self)
	DebugPanel.add_button("Low fuel", _debug_low_fuel, self)
	DebugPanel.add_button("Scare passengers", _debug_scare_passengers, self)
	DebugPanel.add_button("Incoming transmission", _debug_incoming_transmission, self)
	DebugPanel.add_button("Test notices", _debug_test_notices, self)
	DebugPanel.add_button("Serve games lab", SceneFlow.go_to.bind(SERVE_LAB_SCENE), self)
	var percent := StatModifier.Kind.PERCENT
	_add_stat_buttons(BusStats.Type.MAX_SPEED, percent, STAT_PERCENT, "% top speed")
	_add_stat_buttons(BusStats.Type.FUEL_CAPACITY, percent, STAT_PERCENT, "% fuel tank")
	_add_stat_buttons(BusStats.Type.SEATS, StatModifier.Kind.FLAT, SEATS, " seat")
	_add_stat_buttons(BusStats.Type.PORTION_SIZE, percent, STAT_PERCENT, "% portions")
	for value: int in BusTraits.Type.values():
		var text := "Toggle %s" % String(BusTraits.Type.keys()[value]).capitalize().to_lower()
		var action := _debug_toggle_trait.bind(value as BusTraits.Type)
		DebugPanel.add_button(text, action, self, TRAITS_GROUP)
	for mode: ServeMinigamePrototype.Mode in ServeMinigamePrototype.NAMES:
		var pick := _debug_pick_serve_game.bind(mode)
		DebugPanel.add_button(ServeMinigamePrototype.NAMES[mode], pick, self, SERVE_GROUP)
	DebugPanel.add_button("Everyone asks", _debug_everyone_asks, self, SERVE_GROUP)


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


# Scare passengers: everyone on board takes a kick's shock, without anyone being kicked.
func _debug_scare_passengers() -> void:
	cabin.shock(Cabin.KICK_SHOCK)


# Incoming transmission: the call notice. Nothing answers it yet, so Answer only closes it.
func _debug_incoming_transmission() -> void:
	notices.announce_transmission()


# Test notices: one of each other kind, the info closing by itself and the warning with a
# close button.
func _debug_test_notices() -> void:
	notices.push("Right-click a planet to add it to the route.", Notice.Kind.TUTORIAL, true)
	notices.push("The tank is full.", Notice.Kind.INFO, false, 4.0)
	notices.push("Fuel is running low.", Notice.Kind.WARNING, true)
	notices.push("Not enough credits.", Notice.Kind.ERROR, false, 4.0)


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
