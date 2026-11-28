class_name GateService
extends Node
## Sells trips through the warp gates ([WarpGate]): while the bus is docked at a planet with
## a gate, the dock panel's warp button reads where it goes and what it costs, and is on
## while the tank holds that much and the bus can go. A right click on that gate in the world,
## as on a stop, does what the button does, and the pointer on it shows the way as the
## button's does. Pressed, the fuel comes out of the tank
## and the bus warps through the gate as it jumps between star systems ([method SystemJump.warp]),
## coming out of the other gate and flying the short way in to dock at its planet. Its
## course is gone; whoever is on board rides along. With Gate tuning it costs
## [constant TUNED_SHARE] of what the gate asks.

## The bus came out of the far gate, with whoever is on board.
signal warped

const TEXT := "Warp to %s (%d%% fuel)"
const TUNED_SHARE := 0.5

@export var bus: FrameshiftBus
@export var dock_panel: DockPanel
## Nobody teleports while passengers get off or on.
@export var cabin: Cabin
## Plays the warp.
@export var system_jump: SystemJump


func _ready() -> void:
	dock_panel.teleport_pressed.connect(_on_teleport_pressed)
	system_jump.came_through.connect(_on_came_through)


func _process(_delta: float) -> void:
	var gate := _gate()
	var viewport := get_viewport()
	dock_panel.gate_hovered = (
		gate != null
		and not viewport.gui_get_hovered_control()
		and _is_on_gate(gate, viewport.get_mouse_position())
	)
	if not gate:
		dock_panel.show_teleport("", false)
		return
	dock_panel.show_teleport(get_offer(gate), _can_go() and _can_pay(gate))


# Before the solar system sees the press, so a right click on the gate never sets a course,
# whether it warps or the bus can't go or pay.
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if not click or not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var gate := _gate()
	if not gate or not _is_on_gate(gate, click.position):
		return
	get_viewport().set_input_as_handled()
	_on_teleport_pressed()


## What going through [param gate] offers: where it leads and the fuel it takes, as the
## warp button reads. Empty unless it is the gate beside the planet the bus is docked at.
func get_offer(gate: WarpGate) -> String:
	if not gate or gate != _gate():
		return ""
	return TEXT % [gate.partner.planet.display_name, roundi(_fuel_share(gate) * 100.0)]


# The gate beside the planet the bus is docked at, when it leads somewhere.
func _gate() -> WarpGate:
	if not bus.is_at_planet():
		return null
	var gate := WarpGate.of(bus.get_docked_planet())
	return gate if gate and gate.partner and gate.partner.planet else null


# Whether [param pointer] is on [param gate] on screen.
func _is_on_gate(gate: WarpGate, pointer: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera != null and WarpGate.under(camera, pointer) == gate


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
	return tank.fuel >= _fuel_share(gate) * tank.capacity


func _on_teleport_pressed() -> void:
	var gate := _gate()
	if not gate or not _can_go() or not _can_pay(gate):
		return
	var tank := bus.get_fuel_tank()
	tank.fuel -= _fuel_share(gate) * tank.capacity
	system_jump.warp(gate, gate.partner)


# The share of a full tank going through [param gate] takes: less with Gate tuning.
func _fuel_share(gate: WarpGate) -> float:
	var tuned := bus.get_stats().get_traits().has(BusTraits.Type.GATE_TUNING)
	return gate.fuel_share * (TUNED_SHARE if tuned else 1.0)


func _on_came_through(_gate: WarpGate) -> void:
	warped.emit()
