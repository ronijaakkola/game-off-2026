class_name FuelPump
extends Node
## Sells the bus fuel at the planet it is docked at while the player holds a fuel button:
## fuel flows slowly at first and faster the longer they hold, and costs the planet's fuel
## price. The bill is paid once the pump stops, when they let go, the tank is full, the
## credits run out or the bus leaves: the whole credits it adds up to come off the credits
## together, and what is left under a credit carries over to the next refuel.
## [member sound] plays from the moment fuel starts to flow until it stops, however that
## happens.
## The button is the dock panel's fuel button, and each frame it shows there whether it
## can pump.

## Fuel a second the pump gives as the button goes down, the most it speeds up to, and the
## seconds it takes to get there.
const START_RATE := 12.0
const MAX_RATE := 60.0
const RAMP_SECONDS := 1.5

## One cycle of the pump's sound. It repeats while the pump runs, so its import loops it
## (a clip that loops cleanly), and its pitch rises the longer the pump runs: from
## [member pitch_start] as fuel starts to flow to [member pitch_end] after
## [member pitch_rise_seconds], slower than the flow itself speeds up. The sound fades out
## over [member fade_seconds] when the pump stops, so it doesn't click.
@export var sound: AudioStream
@export_range(0.0, 1.0, 0.01) var sound_volume := 1.0
@export_range(0.1, 4.0, 0.01) var pitch_start := 0.6
@export_range(0.1, 4.0, 0.01) var pitch_end := 1.0
@export_range(0.1, 10.0, 0.1, "or_greater") var pitch_rise_seconds := 2.0
@export_range(0.0, 1.0, 0.01) var fade_seconds := 0.34
## The bus whose tank it fills, at the planet it is docked at.
@export var bus: FrameshiftBus
## The panel whose fuel button it runs on.
@export var dock_panel: DockPanel

## The credits that pay for fuel. The parent sets it; without one, it does nothing.
var ledger: Ledger

# Seconds the pump has run since the button went down.
var _pump_time := 0.0
# Credits owed for fuel pumped but not yet paid: this refuel's bill while the pump runs,
# and under one credit, carried over, once it has stopped.
var _owed := 0.0
var _player: AudioStreamPlayer
var _sounding := false
var _fade: Tween


func _ready() -> void:
	# Its own player, not Audio.play_sfx: the sound has to stop when the pump does.
	_player = AudioStreamPlayer.new()
	_player.stream = sound
	_player.bus = Audio.BUS_NAMES[Audio.Bus.SFX]
	add_child(_player)


func _process(delta: float) -> void:
	if not bus or not ledger:
		return
	var tank := bus.get_fuel_tank()
	var docked: Planet = bus.get_docked_planet() if bus.is_at_planet() else null
	var reason := get_stop(docked, tank, ledger) if docked else ""
	var fill_cost := ceili((tank.capacity - tank.fuel) * docked.fuel_price) if docked else 0
	var can_fuel := docked != null and reason.is_empty()
	dock_panel.show_fuel(tank.get_fraction(), fill_cost, can_fuel, reason.trim_suffix("."))
	if docked:
		run(delta, docked, dock_panel.is_fuel_held(), tank, ledger)
	else:
		stop(ledger)


## Why [param tank] can't take fuel at [param planet] now, or "" when it can.
func get_stop(planet: Planet, tank: FuelTank, ledger: Ledger) -> String:
	if not planet.sells_fuel:
		return "No fuel sold here."
	if tank.fuel >= tank.capacity:
		return "Tank full."
	if _affordable(planet, ledger) <= 0.0:
		return "Not enough credits."
	return ""


## Pumps [param delta] seconds of fuel into [param tank] at [param planet] while
## [param held] and nothing stops it, adding to the bill. Otherwise the pump stops and pays
## the bill from [param ledger], and starts slow again next time.
func run(delta: float, planet: Planet, held: bool, tank: FuelTank, ledger: Ledger) -> void:
	if not held or not get_stop(planet, tank, ledger).is_empty():
		stop(ledger)
		return
	_set_sounding(true)
	_pump_time += delta
	var ramp := clampf(_pump_time / RAMP_SECONDS, 0.0, 1.0)
	var rise := clampf(_pump_time / pitch_rise_seconds, 0.0, 1.0)
	_player.pitch_scale = lerpf(pitch_start, pitch_end, rise)
	var amount := minf(lerpf(START_RATE, MAX_RATE, ramp) * delta, _affordable(planet, ledger))
	amount = minf(amount, tank.capacity - tank.fuel)
	tank.refuel(amount)
	_owed += amount * planet.fuel_price


## Stops the pump, if it runs, and pays its bill from [param ledger] in whole credits.
func stop(ledger: Ledger) -> void:
	_pump_time = 0.0
	_set_sounding(false)
	var whole := floori(_owed)
	if whole > 0:
		ledger.spend(whole)
		_owed -= whole


# Starts the sound from the top, or fades it out; asking for what it already does is
# nothing, since the parent calls this every frame.
func _set_sounding(on: bool) -> void:
	if on == _sounding or not _player or not _player.stream:
		return
	_sounding = on
	if _fade:
		_fade.kill()
		_fade = null
	if on:
		_player.volume_linear = sound_volume
		_player.pitch_scale = pitch_start
		_player.play()
		return
	_fade = create_tween()
	_fade.tween_property(_player, ^"volume_linear", 0.0, fade_seconds)
	_fade.tween_callback(_player.stop)


# How much fuel the credits left buy at [param planet].
func _affordable(planet: Planet, ledger: Ledger) -> float:
	if planet.fuel_price <= 0.0:
		return INF
	return maxf(ledger.credits - _owed, 0.0) / planet.fuel_price
