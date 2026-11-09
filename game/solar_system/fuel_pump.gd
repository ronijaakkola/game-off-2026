class_name FuelPump
extends Node
## Sells the bus fuel at the planet it is docked at while the player holds a fuel button:
## fuel flows slowly at first and faster the longer they hold, and costs the planet's fuel
## price. The bill is paid once the pump stops, when they let go, the tank is full, the
## credits run out or the bus leaves: the whole credits it adds up to come off the credits
## together, and what is left under a credit carries over to the next refuel. The parent
## says each frame whether a button is held.

## Fuel a second the pump gives as the button goes down, the most it speeds up to, and the
## seconds it takes to get there.
const START_RATE := 12.0
const MAX_RATE := 60.0
const RAMP_SECONDS := 1.5

# Seconds the pump has run since the button went down.
var _pump_time := 0.0
# Credits owed for fuel pumped but not yet paid: this refuel's bill while the pump runs,
# and under one credit, carried over, once it has stopped.
var _owed := 0.0


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
	_pump_time += delta
	var ramp := clampf(_pump_time / RAMP_SECONDS, 0.0, 1.0)
	var amount := minf(lerpf(START_RATE, MAX_RATE, ramp) * delta, _affordable(planet, ledger))
	amount = minf(amount, tank.capacity - tank.fuel)
	tank.refuel(amount)
	_owed += amount * planet.fuel_price


## Stops the pump, if it runs, and pays its bill from [param ledger] in whole credits.
func stop(ledger: Ledger) -> void:
	_pump_time = 0.0
	var whole := floori(_owed)
	if whole > 0:
		ledger.spend(whole)
		_owed -= whole


# How much fuel the credits left buy at [param planet].
func _affordable(planet: Planet, ledger: Ledger) -> float:
	if planet.fuel_price <= 0.0:
		return INF
	return maxf(ledger.credits - _owed, 0.0) / planet.fuel_price
