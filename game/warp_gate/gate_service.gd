class_name GateService
extends Node
## Sells trips through the warp gates ([WarpGate]): while the bus is docked at a planet with
## a gate, the dock panel's warp button reads where it goes and what it costs, and is on
## while the tank holds that much and the bus can go. Pressed, the fuel comes out of the tank
## and the bus warps through the gate as it jumps between star systems ([method SystemJump.warp]),
## coming out of the other gate and flying the short way in to dock at its planet. Its
## course is gone; whoever is on board rides along.

const TEXT := "Warp to %s (%d%% fuel)"

@export var bus: FrameshiftBus
@export var dock_panel: DockPanel
## Nobody teleports while passengers get off or on.
@export var cabin: Cabin
## Plays the warp.
@export var system_jump: SystemJump


func _ready() -> void:
	dock_panel.teleport_pressed.connect(_on_teleport_pressed)


func _process(_delta: float) -> void:
	var gate := _gate()
	if not gate:
		dock_panel.show_teleport("", false)
		return
	var text := TEXT % [gate.partner.planet.display_name, roundi(gate.fuel_share * 100.0)]
	dock_panel.show_teleport(text, _can_go() and _can_pay(gate))


# The gate beside the planet the bus is docked at, when it leads somewhere.
func _gate() -> WarpGate:
	if not bus.is_at_planet():
		return null
	var gate := WarpGate.of(bus.get_docked_planet())
	return gate if gate and gate.partner and gate.partner.planet else null


# Whether the bus can go now: docked and still, with no stop or call under way.
func _can_go() -> bool:
	if bus.state != FrameshiftBus.State.DOCKED or bus.route_locked:
		return false
	if system_jump.is_jumping():
		return false
	return not cabin.is_stopping()


# Whether the tank holds the fuel going through [param gate] takes.
func _can_pay(gate: WarpGate) -> bool:
	var tank := bus.get_fuel_tank()
	return tank.fuel >= gate.fuel_share * tank.capacity


func _on_teleport_pressed() -> void:
	var gate := _gate()
	if not gate or not _can_go() or not _can_pay(gate):
		return
	var tank := bus.get_fuel_tank()
	tank.fuel -= gate.fuel_share * tank.capacity
	system_jump.warp(gate, gate.partner)
